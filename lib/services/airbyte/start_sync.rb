# frozen_string_literal: true

module Services
  module Airbyte
    # Starts a new Airbyte sync and returns its job ID
    class StartSync
      class Error < StandardError; end

      def self.call(access_token:, connection_id:)
        new(access_token:, connection_id:).call
      end

      def initialize(access_token:, connection_id:)
        @access_token = access_token
        @connection_id = connection_id
      end

      def call
        payload = { connectionId: @connection_id }

        response = Services::Airbyte::ApiServer.post(
          path: '/api/v1/connections/sync',
          access_token: @access_token,
          payload:
        )

        job_id = response.dig('job', 'id')
        raise Error, 'No job ID returned from StartSync' unless job_id

        job_id
      rescue StandardError => e
        Rails.logger.error("StartSync failed: #{e.message}")
        raise Error, e.message
      end
    end
  end
end
