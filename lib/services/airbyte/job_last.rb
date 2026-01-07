# frozen_string_literal: true

module Services
  module Airbyte
    # Returns the last Airbyte sync job for a connection
    class JobLast
      class Error < StandardError; end

      PAGE_SIZE = 5

      def self.call(access_token:)
        new(access_token:).call
      end

      def initialize(access_token:)
        @access_token = access_token
      end

      def call
        payload = {
          configTypes: ['sync'],
          configId: DfE::Analytics.config.airbyte_configuration[:connection_id],
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
