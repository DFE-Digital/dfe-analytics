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
        url = "#{config.airbyte_server_url}/api/v1/applications/token"

        response = http_post(url)

        # Handle HTTP non-success without rescue catching it
        return parse_token(response) if response.success?

        handle_http_error(response, url)
      rescue StandardError => e
        # Only network/transport failures should end up here
        Rails.logger.error("HTTP post failed to url: #{url}, failed with error: #{e.message}")
        raise Error, e.message
      end

      private

      def http_post(url)
        HTTParty.post(
          url,
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
      end

      def parse_token(response)
        response.parsed_response['access_token']
      end

      def handle_http_error(response, _url)
        message = "Error calling Airbyte token API: status: #{response.code} body: #{response.body}"
        Rails.logger.error(message)
        raise Error, message
      end

      def config
        DfE::Analytics.config
      end
    end
  end
end
