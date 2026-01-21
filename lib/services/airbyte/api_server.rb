# frozen_string_literal: true

module Services
  module Airbyte
    # A lightweight HTTP client wrapper for Airbyte API calls
    class ApiServer
      class Error < StandardError; end

      # Custom HTTP Error class if clients require this
      class HttpError < Error
        attr_reader :code

        def initialize(code, message)
          @code = code
          super(message)
        end
      end

      def self.post(path:, access_token:, payload:)
        new(path:, access_token:, payload:, method: :post).call
      end

      def self.patch(path:, access_token:, payload:)
        new(path:, access_token:, payload:, method: :patch).call
      end

      def initialize(path:, access_token:, payload:, method:)
        @path = path
        @access_token = access_token
        @payload = payload
        @method = method
      end

      def call
        # Only :post and :patch are supported. This is internally controlled.
        response =
          case @method
          when :post then HTTParty.post(url, request_options)
          when :patch then HTTParty.patch(url, request_options)
          end

        handle_http_error(response)

        response.parsed_response
      rescue HttpError
        raise
      rescue StandardError => e
        Rails.logger.error("HTTP #{@method} failed to url: #{url}, failed with error: #{e.message}")
        raise Error, e.message
      end

      private

      def url
        "#{DfE::Analytics.config.airbyte_server_url}#{@path}"
      end

      def request_options
        {
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{@access_token}"
          },
          body: @payload.to_json
        }
      end

      def handle_http_error(response)
        return if response.success?

        error_message = "Error calling Airbyte API (#{@path}): method: #{@method} status: #{response.code} body: #{response.body}"
        Rails.logger.info(error_message)
        raise HttpError.new(response.code, response.body)
      end
    end
  end
end
