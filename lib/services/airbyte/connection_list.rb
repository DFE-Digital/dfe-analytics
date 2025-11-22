# frozen_string_literal: true

module Services
  module Airbyte
    # Fetches the connection info for given workspace - Assumes single connection
    class ConnectionList
      class Error < StandardError; end

      def self.call(access_token:)
        new(access_token:).call
      end

      def initialize(access_token:)
        @access_token = access_token
      end

      def call
        payload = {
          workspaceId: config.airbyte_workspace_id
        }

        response = Services::Airbyte::ApiServer.post(
          path: '/api/v1/connections/list',
          access_token: @access_token,
          payload:
        )

        connection = response.dig('connections', 0)

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
