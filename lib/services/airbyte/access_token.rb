# frozen_string_literal: true

module Services
  module Airbyte
    # Fetches access token for Airbyte API calls
    class AccessToken
      class Error < StandardError; end

      def self.call
        new.call
      end

      def call
        response = HTTParty.post(
          "#{config.airbyte_server_url}/api/v1/applications/token",
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          },
          body: {
            client_id: config.airbyte_client_id,
            client_secret: config.airbyte_client_secret,
            'grant-type': 'client_credentials'
          }.to_json
        )

        unless response.success?
          error_message = "Error calling Airbyte token API: status: #{response.code} body: #{response.body}"
          Rails.logger.error(error_message)
          raise Error, error_message
        end

        response.parsed_response['access_token']
      end

      private

      def config
        DfE::Analytics.config
      end
    end
  end
end
