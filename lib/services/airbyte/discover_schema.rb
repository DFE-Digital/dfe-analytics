# frozen_string_literal: true

module Services
  module Airbyte
    # Fetches the the current schema for given source - Also reloads cache
    class DiscoverSchema
      class Error < StandardError; end

      def self.call(access_token:, source_id:)
        new(access_token, source_id).call
      end

      def initialize(access_token, source_id)
        @access_token = access_token
        @source_id = source_id
      end

      def call
        response = HTTParty.post(
          "#{config.airbyte_server_url}/api/v1/sources/discover_schema",
          headers: {
            'Authorization' => "Bearer #{@access_token}",
            'Content-Type' => 'application/json'
          },
          body: {
            sourceId: @source_id
          }.to_json
        )

        unless response.success?
          error_message = "Error calling Airbyte discover_schema API: status: #{response.code} body: #{response.body}"
          Rails.logger.error(error_message)
          raise Error, error_message
        end

        response.parsed_response
      end

      private

      def config
        DfE::Analytics.config
      end
    end
  end
end
