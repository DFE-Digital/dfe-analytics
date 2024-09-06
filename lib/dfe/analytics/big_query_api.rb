# frozen_string_literal: true

module DfE
  module Analytics
    # For use with for workload identity federeation
    class BigQueryApi
      def self.events_client
        @events_client ||= begin
          # Load v2 APIs
          require 'google/apis/bigquery_v2'

          missing_config = %i[
            bigquery_project_id
            bigquery_table_name
            bigquery_dataset
            azure_client_id
            azure_token_path
            azure_scope
            gcp_scope
            google_cloud_credentials
          ].select { |val| DfE::Analytics.config.send(val).blank? }

          raise(ConfigurationError, "DfE::Analytics: missing required config values: #{missing_config.join(', ')}") if missing_config.any?

          Google::Apis::BigqueryV2::BigqueryService.new
        end

        @events_client.authorization = DfE::Analytics::AzureFederatedAuth.gcp_client_credentials
        @events_client
      end

      def self.insert(events)
        rows         = events.map { |event| { json: event } }
        data_request = Google::Apis::BigqueryV2::InsertAllTableDataRequest.new(rows: rows, skip_invalid_rows: true)
        options      = Google::Apis::RequestOptions.new(retries: DfE::Analytics.config.bigquery_retries)

        response =
          events_client.insert_all_table_data(
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

      class ConfigurationError < StandardError; end
      class SendEventsError < StandardError; end
    end
  end
end
