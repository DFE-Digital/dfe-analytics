# frozen_string_literal: true

module DfE
  module Analytics
    # For use with legacy authentication with fixed api key
    class BigQueryLegacyApi
      def self.events_client
        @events_client ||= begin
          # Load v1 APIs
          require 'google/cloud/bigquery'

          # Check for missing config items - otherwise may get obscure api errors
          missing_config = %i[
            bigquery_project_id
            bigquery_table_name
            bigquery_dataset
            bigquery_api_json_key
          ].select { |val| DfE::Analytics.config.send(val).blank? }

          raise(ConfigurationError, "DfE::Analytics: missing required config values: #{missing_config.join(', ')}") if missing_config.any?

          Google::Cloud::Bigquery.new(
            project: DfE::Analytics.config.bigquery_project_id,
            credentials: JSON.parse(DfE::Analytics.config.bigquery_api_json_key),
            retries: DfE::Analytics.config.bigquery_retries,
            timeout: DfE::Analytics.config.bigquery_timeout
          ).dataset(DfE::Analytics.config.bigquery_dataset, skip_lookup: true)
           .table(DfE::Analytics.config.bigquery_table_name, skip_lookup: true)
        end
      end

      def self.insert(events)
        response = events_client.insert(events, ignore_unknown: true)

        return if response.success?

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
          .error_rows
          .map { |error_row| "index: #{response.index_for(error_row)} error: #{response.errors_for(error_row)} error_row: #{error_row}" }
          .compact.join("\n")

        "DfE::Analytics BigQuery API insert error for #{response.error_rows.length} event(s): response error count: #{response.error_count}\n#{message}"
      end

      class ConfigurationError < StandardError; end
      class SendEventsError < StandardError; end
    end
  end
end
