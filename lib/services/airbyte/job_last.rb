# frozen_string_literal: true

module Services
  module Airbyte
    # Returns the last Airbyte sync job for a connection
    class JobLast
      class Error < StandardError; end

      PAGE_SIZE = 5

      def self.call(access_token:, connection_id:)
        new(access_token:, connection_id:).call
      end

      def initialize(access_token:, connection_id:)
        @access_token = access_token
        @connection_id = connection_id
      end

      def call
        payload = {
          configTypes: ['sync'],
          configId: @connection_id,
          pagination: { pageSize: PAGE_SIZE, rowOffset: 0 }
        }

        response = Services::Airbyte::ApiServer.post(
          path: '/api/v1/jobs/list',
          access_token: @access_token,
          payload:
        )

        response['jobs']&.first
      rescue StandardError => e
        Rails.logger.error(e.message)
        raise Error, e.message
      end
    end
  end
end
