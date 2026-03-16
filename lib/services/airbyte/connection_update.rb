# frozen_string_literal: true

module Services
  module Airbyte
    # Fetches the the current schema for given source - Also reloads cache
    class ConnectionUpdate
      def self.call(access_token:)
        new(access_token).call
      end

      def initialize(access_token)
        @access_token = access_token
        @connection_id = DfE::Analytics.config.airbyte_configuration[:connection_id]
      end

      def call
        Services::Airbyte::ApiServer.patch(
          path: "/api/public/v1/connections/#{@connection_id}",
          access_token: @access_token,
          payload: airbyte_stream_config
        )
      end

      private

      def airbyte_stream_config
        DfE::Analytics::AirbyteStreamConfig.generate_for(DfE::Analytics.allowlist)
      end
    end
  end
end
