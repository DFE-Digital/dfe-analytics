# frozen_string_literal: true

module DfE
  module Analytics
    # For use with for workload identity federation
    class BigQueryApi
      # All times are in seconds
      ALL_RETRIES_MAX_ELASPED_TIME = 120
      RETRY_INITIAL_BASE_INTERVAL = 15
      RETRY_MAX_INTERVAL = 60
      RETRY_INTERVAL_MULTIPLIER = 2
      BIGQUERY_MANDATORY_CONFIG = %i[
        bigquery_project_id
        bigquery_table_name
        bigquery_dataset
        azure_client_id
        azure_token_path
        azure_scope
        gcp_scope
        google_cloud_credentials
      ].freeze
      BIGQUERY_AIRBYTE_MANDATORY_CONFIG = %i[
        bigquery_airbyte_dataset
        bigquery_hidden_policy_tag
      ].freeze

      def self.client
        @client ||= begin
          DfE::Analytics::Config.check_missing_config!(BIGQUERY_MANDATORY_CONFIG)
          DfE::Analytics::Config.check_missing_config!(BIGQUERY_AIRBYTE_MANDATORY_CONFIG) if DfE::Analytics.airbyte_enabled?

          Google::Apis::BigqueryV2::BigqueryService.new
        end

        @client.authorization = DfE::Analytics::AzureFederatedAuth.gcp_client_credentials
        @client
      end

      def self.insert(events)
        rows            = events.map { |event| { json: event } }
        data_request    = Google::Apis::BigqueryV2::InsertAllTableDataRequest.new(rows: rows, skip_invalid_rows: true)
        options         = Google::Apis::RequestOptions.default

        options.authorization    = client.authorization
        options.retries          = DfE::Analytics.config.bigquery_retries
        options.max_elapsed_time = ALL_RETRIES_MAX_ELASPED_TIME
        options.base_interval    = RETRY_INITIAL_BASE_INTERVAL
        options.max_interval     = RETRY_MAX_INTERVAL
        options.multiplier       = RETRY_INTERVAL_MULTIPLIER

        response =
          client.insert_all_table_data(
            DfE::Analytics.config.bigquery_project_id,
            DfE::Analytics.config.bigquery_dataset,
            DfE::Analytics.config.bigquery_table_name,
            data_request,
            options: options
          )

        return unless response.insert_errors.present?

        event_count   = events.length
        error_message = error_message_for(response)

        Rails.logger.error(error_message)

        events.each.with_index(1) do |event, index|
          Rails.logger.info("DfE::Analytics possible error processing event (#{index}/#{event_count}): #{event.inspect}")
        end

        raise SendEventsError, error_message
      end

      def self.error_message_for(response)
        message =
          response
          .insert_errors
          .map { |insert_error| "index: #{insert_error.index} error: #{insert_error.errors.map(&:message).join(' ')} insert_error: #{insert_error}" }
          .compact.join("\n")

        "DfE::Analytics BigQuery API insert error for #{response.insert_errors.length} event(s):\n#{message}"
      end

      def self.apply_policy_tags(tables, policy_tag)
        tables.each do |table_name, column_names|
          begin
            table = client.get_table(
              DfE::Analytics.config.bigquery_project_id,
              DfE::Analytics.config.bigquery_airbyte_dataset,
              table_name.to_s
            )
          rescue Google::Apis::ClientError => e
            error_message = "DfE::Analytics Failed to retrieve table: #{table_name}: #{e.message}"
            Rails.logger.error(error_message)
            raise PolicyTagError, error_message
          end

          updated_fields = table.schema.fields.map do |field|
            field.policy_tags = Google::Apis::BigqueryV2::TableFieldSchema::PolicyTags.new(names: [policy_tag]) if column_names.include?(field.name)
            field
          end

          new_schema = Google::Apis::BigqueryV2::TableSchema.new(fields: updated_fields)
          updated_table = Google::Apis::BigqueryV2::Table.new(schema: new_schema)

          begin
            client.patch_table(
              DfE::Analytics.config.bigquery_project_id,
              DfE::Analytics.config.bigquery_airbyte_dataset,
              table_name.to_s,
              updated_table,
              fields: 'schema'
            )
          rescue Google::Apis::ClientError => e
            error_message = "DfE::Analytics  Failed to update table: #{table_name}: #{e.message}"
            Rails.logger.error(error_message)
            raise PolicyTagError, error_message
          end
        end
      end

      class SendEventsError < StandardError; end
      class PolicyTagError < StandardError; end
    end
  end
end
