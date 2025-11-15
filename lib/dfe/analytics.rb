# frozen_string_literal: true

require 'request_store_rails'
require 'i18n'
require 'httparty'
require 'google/cloud/bigquery'
require 'dfe/analytics/activerecord' if defined?(ActiveRecord)
require 'dfe/analytics/config'
require 'dfe/analytics/event_schema'
require 'dfe/analytics/fields'
require 'dfe/analytics/entities'
require 'dfe/analytics/shared/service_pattern'
require 'dfe/analytics/concerns/requestable'
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
require 'dfe/analytics/big_query_api'
require 'dfe/analytics/big_query_legacy_api'
require 'dfe/analytics/azure_federated_auth'
require 'dfe/analytics/api_requests'
require 'dfe/analytics/airbyte_stream_config'
require 'dfe/analytics/big_query_apply_policy_tags_job'
require 'dfe/analytics/airbyte_deploy_job'
require 'dfe/analytics/services'
require 'services/airbyte'

module DfE
  module Analytics
    class ConfigurationError < StandardError; end

    def self.config
      @config ||= DfE::Analytics::Config.params
    end

    def self.configure
      yield(config)

      DfE::Analytics::Config.configure(config)
    end

    def self.initialize!
      unless Rails.env.production? || File.exist?(Rails.root.join('config/initializers/dfe_analytics.rb'))
        message = "Warning: DfE Analytics is not set up. Run: 'bundle exec rails generate dfe:analytics:install'"
        Rails.logger.error(message)
        puts message
        return
      end

      if defined?(ActiveRecord) && database_events_enabled?
        setup_entities
      else
        Rails.logger.info('ActiveRecord not defined or database events not enabled; DfE Analytics will only track non-database events.')
      end
    end

    def self.setup_entities
      if Rails.version.to_f > 7.1
        ActiveRecord::Base.with_connection do |connection|
          raise ActiveRecord::PendingMigrationError if connection.pool.migration_context.needs_migration?
        end
      elsif ActiveRecord::Base.connection.migration_context.needs_migration?
        raise ActiveRecord::PendingMigrationError
      end

      DfE::Analytics::Fields.check!

      entities_for_analytics.each do |entity|
        models_for_entity(entity).each do |m|
          m.include(DfE::Analytics::TransactionChanges)
          if m.include?(DfE::Analytics::Entities)
            Rails.logger.warn("DEPRECATION WARNING: DfE::Analytics::Entities was manually included in a model (#{m.name}), but it's included automatically since v1.4. You're running v#{DfE::Analytics::VERSION}. To silence this warning, remove the include from model definitions in app/models.")
          else
            m.include(DfE::Analytics::Entities)
            break
          end
        end
      end
    rescue ActiveRecord::PendingMigrationError
      Rails.logger.error('Database requires migration; DfE Analytics not initialized')
    rescue ActiveRecord::ActiveRecordError
      Rails.logger.error('No database connection; DfE Analytics not initialized')
    end

    def self.enabled?
      config.enable_analytics.call
    end

    def self.allowlist
      Rails.application.config_for(:analytics)
    end

    def self.hidden_pii
      Rails.application.config_for(:analytics_hidden_pii)
    rescue RuntimeError
      { 'shared' => {} }
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

    def self.airbyte_stream_config
      JSON.parse(File.read(DfE::Analytics.config.airbyte_stream_config_path)).deep_symbolize_keys
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
      table_name = model.class.table_name.to_sym

      exportable_attrs = (allowlist[table_name].presence || []).map(&:to_sym)
      hidden_pii_attrs = (hidden_pii[table_name].presence || []).map(&:to_sym)
      exportable_hidden_pii_attrs = exportable_attrs & hidden_pii_attrs

      # Exclude hidden pii attributes from allowed_attributes
      allowed_attrs_to_include = exportable_attrs - exportable_hidden_pii_attrs
      allowed_attributes = attributes.slice(*allowed_attrs_to_include&.map(&:to_s))
      hidden_attributes = attributes.slice(*exportable_hidden_pii_attrs&.map(&:to_s))

      # Allowed attributes must be kept separate from hidden_attributes
      {}.tap do |model_attributes|
        model_attributes[:data] = allowed_attributes if allowed_attributes.any?
        model_attributes[:hidden_data] = hidden_attributes if hidden_attributes.any?
      end
    end

    def self.anonymise(value)
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
          .reject(&DfE::Analytics.config.excluded_models_proc)
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

    def self.database_events_enabled?
      config.database_events_enabled
    end

    def self.airbyte_enabled?
      config.airbyte_enabled
    end

    def self.parse_maintenance_window
      return [nil, nil] unless config.bigquery_maintenance_window

      start_str, end_str = config.bigquery_maintenance_window.split('..', 2).map(&:strip)
      begin
        parsed_start_time = DateTime.strptime(start_str, '%d-%m-%Y %H:%M')
        parsed_end_time = DateTime.strptime(end_str, '%d-%m-%Y %H:%M')

        start_time = Time.zone.parse(parsed_start_time.to_s)
        end_time = Time.zone.parse(parsed_end_time.to_s)

        if start_time > end_time
          Rails.logger.warn('Start time is after end time in maintenance window configuration')
          return [nil, nil]
        end

        [start_time, end_time]
      rescue ArgumentError => e
        Rails.logger.error("DfE::Analytics: Unexpected error in maintenance window configuration: #{e.message}")
        [nil, nil]
      end
    end

    def self.within_maintenance_window?
      start_time, end_time = parse_maintenance_window
      return false unless start_time && end_time

      Time.zone.now.between?(start_time, end_time)
    end

    def self.next_scheduled_time_after_maintenance_window
      start_time, end_time = parse_maintenance_window
      return unless start_time && end_time

      end_time + (Time.zone.now - start_time).seconds
    end
  end
end
