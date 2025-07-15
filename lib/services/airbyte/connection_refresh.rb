# frozen_string_literal: true

module Services
  module Airbyte
    # Refreshes an Airbyte connection: gets token, schema, and updates the connection
    class ConnectionRefresh
      class Error < StandardError; end

      def self.call
        new.call
      end

      def call
        access_token = AccessToken.call
        connection_id, source_id = ConnectionList.call(access_token:)
        discovered_schema = DiscoverSchema.call(access_token:, source_id:)
        allowed_list = DfE::Analytics.allowlist

        ConnectionUpdate.call(access_token:, connection_id:, allowed_list:, discovered_schema:)
      rescue StandardError => e
        Rails.logger.error("Airbyte connection refresh failed: #{e.message}")
        raise Error, "Connection refresh failed: #{e.message}"
      end

      def config
        DfE::Analytics.config
      end
    end
  end
end
