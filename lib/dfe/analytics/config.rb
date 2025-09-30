# frozen_string_literal: true

module DfE
  module Analytics
    # Define and load configuration for DfE Analytics
    module Config
      CONFIGURABLES = %i[
        ignore_default_scope
        log_only
        async
        queue
        bigquery_table_name
        bigquery_project_id
        bigquery_dataset
        bigquery_airbyte_dataset
        bigquery_api_json_key
        bigquery_hidden_policy_tag
        bigquery_retries
        bigquery_timeout
        enable_analytics
        environment
        user_identifier
        entity_table_checks_enabled
        rack_page_cached
        bigquery_maintenance_window
        azure_federated_auth
        azure_client_id
        azure_token_path
        azure_scope
        gcp_scope
        google_cloud_credentials
        excluded_paths
        excluded_models_proc
        database_events_enabled
        airbyte_enabled
        airbyte_stream_config_path
        airbyte_client_id
        airbyte_client_secret
        airbyte_server_url
        airbyte_workspace_id
      ].freeze

      def self.params
        Struct.new(*CONFIGURABLES).new
      end

      def self.configure(config)
        config.ignore_default_scope             ||= false
        config.enable_analytics                 ||= proc { true }
        config.bigquery_table_name              ||= ENV.fetch('BIGQUERY_TABLE_NAME', nil)
        config.bigquery_project_id              ||= ENV.fetch('BIGQUERY_PROJECT_ID', nil)
        config.bigquery_dataset                 ||= ENV.fetch('BIGQUERY_DATASET', nil)
        config.bigquery_airbyte_dataset         ||= ENV.fetch('BIGQUERY_AIRBYTE_DATASET', nil)
        config.bigquery_api_json_key            ||= ENV.fetch('BIGQUERY_API_JSON_KEY', nil)
        config.bigquery_hidden_policy_tag       ||= ENV.fetch('BIGQUERY_HIDDEN_POLICY_TAG', nil)
        config.bigquery_retries                 ||= 3
        config.bigquery_timeout                 ||= 120
        config.environment                      ||= ENV.fetch('RAILS_ENV', 'development')
        config.log_only                         ||= false
        config.async                            ||= true
        config.queue                            ||= :default
        config.user_identifier                  ||= proc { |user| user&.id }
        config.entity_table_checks_enabled      ||= false
        config.rack_page_cached                 ||= proc { |_rack_env| false }
        config.bigquery_maintenance_window      ||= ENV.fetch('BIGQUERY_MAINTENANCE_WINDOW', nil)
        config.azure_federated_auth             ||= false
        config.excluded_paths                   ||= []
        config.excluded_models_proc             ||= proc { |_model| false }
        config.database_events_enabled          ||= true
        config.airbyte_enabled                  ||= false
        config.airbyte_client_id                ||= ENV.fetch('AIRBYTE_CLIENT_ID', nil)
        config.airbyte_client_secret            ||= ENV.fetch('AIRBYTE_CLIENT_SECRET', nil)
        config.airbyte_server_url               ||= ENV.fetch('AIRBYTE_SERVER_URL', nil)
        config.airbyte_workspace_id             ||= ENV.fetch('AIRBYTE_WORKSPACE_ID', nil)

        config.airbyte_stream_config_path = File.join(Rails.root, config.airbyte_stream_config_path) if config.airbyte_stream_config_path.present?

        return unless config.azure_federated_auth

        config.azure_client_id          ||= ENV.fetch('AZURE_CLIENT_ID', nil)
        config.azure_token_path         ||= ENV.fetch('AZURE_FEDERATED_TOKEN_FILE', nil)
        config.google_cloud_credentials ||= JSON.parse(ENV.fetch('GOOGLE_CLOUD_CREDENTIALS', '{}')).deep_symbolize_keys
        config.azure_scope              ||= DfE::Analytics::AzureFederatedAuth::DEFAULT_AZURE_SCOPE
        config.gcp_scope                ||= DfE::Analytics::AzureFederatedAuth::DEFAULT_GCP_SCOPE
      end

      def self.check_missing_config!(config)
        missing_config = config.select { |val| DfE::Analytics.config.send(val).blank? }

        raise(ConfigurationError, "DfE::Analytics: missing required config values: #{missing_config.join(', ')}") if missing_config.any?
      end

      class ConfigurationError < StandardError; end
    end
  end
end
