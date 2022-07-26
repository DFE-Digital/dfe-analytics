# frozen_string_literal: true

require 'request_store_rails'
require 'i18n'
require 'dfe/analytics/event_schema'
require 'dfe/analytics/fields'
require 'dfe/analytics/entities'
require 'dfe/analytics/event'
require 'dfe/analytics/analytics_job'
require 'dfe/analytics/send_events'
require 'dfe/analytics/load_entities'
require 'dfe/analytics/load_entity_batch'
require 'dfe/analytics/requests'
require 'dfe/analytics/version'
require 'dfe/analytics/middleware/request_identity'
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
      ]

      @config ||= Struct.new(*configurables).new
    end

    def self.configure
      yield(config)

      config.enable_analytics      ||= proc { true }
      config.bigquery_table_name   ||= ENV['BIGQUERY_TABLE_NAME']
      config.bigquery_project_id   ||= ENV['BIGQUERY_PROJECT_ID']
      config.bigquery_dataset      ||= ENV['BIGQUERY_DATASET']
      config.bigquery_api_json_key ||= ENV['BIGQUERY_API_JSON_KEY']
      config.bigquery_retries      ||= 3
      config.bigquery_timeout      ||= 120
      config.environment           ||= ENV.fetch('RAILS_ENV', 'development')
      config.log_only              ||= false
      config.async                 ||= true
      config.queue                 ||= :default
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

    def self.environment
      config.environment
    end

    def self.log_only?
      config.log_only
    end

    def self.async?
      config.async
    end

    def self.entities_for_analytics
      allowlist.keys & all_entities_in_application
    end

    def self.all_entities_in_application
      entity_model_mapping.keys.map(&:to_sym)
    end

    def self.model_for_entity(entity)
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

      allowed_attributes.deep_merge(obfuscated_attributes.transform_values { |value| anonymise(value) })
    end

    def self.anonymise(value)
      Digest::SHA2.hexdigest(value.to_s)
    end

    def self.entity_model_mapping
      # ActiveRecord::Base.descendants will collect every model in the
      # application, including internal models Rails uses to represent
      # has_and_belongs_to_many relationships without their own models. We map
      # these back to table_names which are equivalent to dfe-analytics
      # "entities".
      @entity_model_mapping ||= begin
        Rails.application.eager_load!

        ActiveRecord::Base.descendants
         .reject(&:abstract_class?)
         .index_by(&:table_name)
      end
    end

    private_class_method :entity_model_mapping
  end
end
