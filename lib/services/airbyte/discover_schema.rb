# frozen_string_literal: true

module Services
  module Airbyte
    # Fetches the the current schema for given source - Also reloads cache
    class DiscoverSchema
      class Error < StandardError; end

      def self.call(access_token:)
        new(access_token).call
      end

      def initialize(access_token)
        @access_token = access_token
      end

      def call
        payload = {
          sourceId: DfE::Analytics.config.airbyte_configuration[:source_id]
        }

        Services::Airbyte::ApiServer.post(
          path: '/api/v1/sources/discover_schema',
          access_token: @access_token,
          payload:
        )
      end
    end
  end
end
