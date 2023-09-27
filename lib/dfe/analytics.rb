# frozen_string_literal: true

require 'request_store_rails'
require 'i18n'
require 'dfe/analytics/event_schema'
require 'dfe/analytics/fields'
require 'dfe/analytics/entities'
require 'dfe/analytics/event'
require 'dfe/analytics/event_matcher'
require 'dfe/analytics/analytics_job'
require 'dfe/analytics/send_events'
require 'dfe/analytics/load_entities'
require 'dfe/analytics/load_entity_batch'
require 'dfe/analytics/requests'
require 'dfe/analytics/entity_table_check_job'
require 'dfe/analytics/initialisation_events'
require 'dfe/analytics/version'
require 'dfe/analytics/middleware/request_identity'
require 'dfe/analytics/middleware/send_cached_page_request_event'
require 'dfe/analytics/railtie'

module DfE
  module Analytics
    class ConfigurationError < StandardError; end

    def self.events_client
      @events_client ||= begin
        require 'google/cloud/bigquery'

        missing_config = %i[
          bigquery_project_id
          bigquery_table_name
          bigquery_dataset
          bigquery_api_json_key
        ].select { |val| config.send(val).nil? }

        raise(ConfigurationError, "DfE::Analytics: missing required config values: #{missing_config.join(', ')}") if missing_config.any?

        Google::Cloud::Bigquery.new(
          project: config.bigquery_project_id,
          credentials: JSON.parse(config.bigquery_api_json_key),
          retries: config.bigquery_retries,
          timeout: config.bigquery_timeout
        ).dataset(config.bigquery_dataset, skip_lookup: true)
                               .table(config.bigquery_table_name, skip_lookup: true)
      end
    end

    def self.config
      configurables = %i[
        log_only
        async
        queue
        bigquery_table_name
        bigquery_project_id
        bigquery_dataset
        bigquery_api_json_key
        bigquery_retries
        bigquery_timeout
        enable_analytics
        environment
        user_identifier
        pseudonymise_web_request_user_id
        entity_table_checks_enabled
        rack_page_cached
      ]

      @config ||= Struct.new(*configurables).new
    end

    def self.configure
      yield(config)

      config.enable_analytics                 ||= proc { true }
      config.bigquery_table_name              ||= ENV.fetch('BIGQUERY_TABLE_NAME', nil)
      config.bigquery_project_id              ||= ENV.fetch('BIGQUERY_PROJECT_ID', nil)
      config.bigquery_dataset                 ||= ENV.fetch('BIGQUERY_DATASET', nil)
      config.bigquery_api_json_key            ||= ENV.fetch('BIGQUERY_API_JSON_KEY', nil)
      config.bigquery_retries                 ||= 3
      config.bigquery_timeout                 ||= 120
      config.environment                      ||= ENV.fetch('RAILS_ENV', 'development')
      config.log_only                         ||= false
      config.async                            ||= true
      config.queue                            ||= :default
      config.user_identifier                  ||= proc { |user| user&.id }
      config.pseudonymise_web_request_user_id ||= false
      config.entity_table_checks_enabled      ||= false
      config.rack_page_cached                 ||= proc { |_rack_env| false }
    end

    def self.initialize!
      unless defined?(ActiveRecord)
        # bail if we don't have AR at all
        Rails.logger.info('ActiveRecord not loaded; DfE Analytics not initialized')
        return
      end

      raise ActiveRecord::PendingMigrationError if ActiveRecord::Base.connection.migration_context.needs_migration?

      DfE::Analytics::Fields.check!

      entities_for_analytics.each do |entity|
        models_for_entity(entity).each do |m|
          if m.include?(DfE::Analytics::Entities)
            Rails.logger.info("DEPRECATION WARNING: DfE::Analytics::Entities was manually included in a model (#{m.name}), but it's included automatically since v1.4. You're running v#{DfE::Analytics::VERSION}. To silence this warning, remove the include from model definitions in app/models.")
          else
            m.include(DfE::Analytics::Entities)
            break
          end
        end
      end
    rescue ActiveRecord::PendingMigrationError
      Rails.logger.info('Database requires migration; DfE Analytics not initialized')
    rescue ActiveRecord::ActiveRecordError
      Rails.logger.info('No database connection; DfE Analytics not initialized')
    end

    def self.enabled?
      config.enable_analytics.call
    end

    def self.allowlist
      Rails.application.config_for(:analytics)
    end

    def self.allowlist_pii
      Rails.application.config_for(:analytics_pii)
    end

    def self.blocklist
      Rails.application.config_for(:analytics_blocklist)
    end

    def self.custom_events
      Rails.application.config_for(:analytics_custom_events)
    rescue RuntimeError
      []
    end

    def self.event_debug_filters
      Rails.application.config_for(:analytics_event_debug)
    rescue RuntimeError
      {}
    end

    def self.environment
      config.environment
    end

    def self.log_only?
      config.log_only
    end

    def self.event_debug_enabled?
      event_debug_filters[:event_filters]&.any?
    end

    def self.async?
      config.async
    end

    def self.entities_for_analytics
      allowlist.keys
    end

    def self.all_entities_in_application
      entity_model_mapping.keys.map(&:to_sym)
    end

    def self.models_for_entity(entity)
      entity_model_mapping.fetch(entity.to_s)
    end

    def self.extract_model_attributes(model, attributes = nil)
      # if no list of attrs specified, consider all attrs belonging to this model
      attributes ||= model.attributes
      table_name = model.class.table_name

      exportable_attrs = allowlist[table_name.to_sym].presence || []
      pii_attrs = allowlist_pii[table_name.to_sym].presence || []
      exportable_pii_attrs = exportable_attrs & pii_attrs

      allowed_attributes = attributes.slice(*exportable_attrs&.map(&:to_s))
      obfuscated_attributes = attributes.slice(*exportable_pii_attrs&.map(&:to_s))

      allowed_attributes.deep_merge(obfuscated_attributes.transform_values { |value| pseudonymise(value) })
    end

    def self.anonymise(value)
      pseudonymise(value)
    end

    def self.pseudonymise(value)
      # Google SQL equivalent of this is TO_HEX(SHA256(value))
      Digest::SHA2.hexdigest(value.to_s)
    end

    def self.entity_model_mapping
      # ActiveRecord::Base.descendants will collect every model in the
      # application, including internal models Rails uses to represent
      # has_and_belongs_to_many relationships without their own models. We map
      # these back to table_names which are equivalent to dfe-analytics
      # "entities".
      @entity_model_mapping ||= begin
        # Gems like devise put helper methods into controllers, and they add
        # those methods via the routes file.
        #
        # Rails.configuration.eager_load = true, which is enabled by default in
        # production and not in development, will cause routes to be loaded
        # before controllers; a direct call to Rails.application.eager_load! will
        # not. To avoid this specific conflict with devise and possibly other
        # gems/engines, proactively load the routes unless
        # configuration.eager_load is set.
        Rails.application.reload_routes! unless Rails.configuration.eager_load

        Rails.application.eager_load!

        rails_tables = %w[ar_internal_metadata schema_migrations]

        ActiveRecord::Base.descendants
          .reject(&:abstract_class?)
          .group_by(&:table_name)
          .except(*rails_tables)
      end
    end

    private_class_method :entity_model_mapping

    def self.user_identifier(user)
      config.user_identifier.call(user)
    end

    def self.rack_page_cached?(rack_env)
      config.rack_page_cached.call(rack_env)
    end

    def self.entity_table_checks_enabled?
      config.entity_table_checks_enabled
    end
  end
end
