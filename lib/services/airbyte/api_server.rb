# frozen_string_literal: true

module Services
  module Airbyte
    # A lightweight HTTP client wrapper for Airbyte API calls
    class ApiServer
      class Error < StandardError; end

      def self.post(path:, access_token:, payload:)
        new(path:, access_token:, payload:).post
      end

      def initialize(path:, access_token:, payload:)
        @path = path
        @access_token = access_token
        @payload = payload
      end

      def post
        url = "#{config.airbyte_server_url}#{@path}"

        response = HTTParty.post(
          url,
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{@access_token}"
          },
          body: @payload.to_json
        )

        unless response.success?
          error_message = "Error calling Airbyte API (#{@path}): status: #{response.code} body: #{response.body}"
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
