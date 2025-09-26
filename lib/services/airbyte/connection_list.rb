# frozen_string_literal: true

module Services
  module Airbyte
    # Fetches the connection info for given workspace - Assumes single connection
    class ConnectionList
      class Error < StandardError; end

      def self.call(access_token:)
        new(access_token).call
      end

      def initialize(access_token)
        @access_token = access_token
      end

      def call
        response = HTTParty.post(
          "#{config.airbyte_server_url}/api/v1/connections/list",
          headers: {
            'Authorization' => "Bearer #{@access_token}",
            'Content-Type' => 'application/json'
          },
          body: {
            workspaceId: config.airbyte_workspace_id
          }.to_json
        )

        unless response.success?
          error_message = "Error calling Airbyte connections/list API: status: #{response.code} body: #{response.body}"
          Rails.logger.error(error_message)
          raise Error, error_message
        end

        connection = response.parsed_response.dig('connections', 0)

        raise Error, 'No connections returned in response.' unless connection

        [connection['connectionId'], connection['sourceId']]
      end

      private

      def config
        DfE::Analytics.config
      end
    end
  end
end
