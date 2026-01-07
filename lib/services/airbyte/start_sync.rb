# frozen_string_literal: true

module Services
  module Airbyte
    # Starts a new Airbyte sync and returns its job ID
    class StartSync
      class Error < StandardError; end

      def self.call(access_token:)
        new(access_token:).call
      end

      def initialize(access_token:)
        @access_token = access_token
      end

      def call
        payload = { connectionId: DfE::Analytics.config.airbyte_configuration[:connection_id] }

        response = Services::Airbyte::ApiServer.post(
          path: '/api/v1/connections/sync',
          access_token:,
          payload:
        )

        job_id_for!(response)
      rescue Services::Airbyte::ApiServer::HttpError => e
        raise unless e.code == 409

        # HTTP Status code: 409 indicates a job is already running - Get last job id
        Rails.logger.info('Sync already in progress, retrieving last job instead.')

        last_job = JobLast.call(access_token:)

        job_id_for!(last_job)
      rescue StandardError => e
        Rails.logger.error("StartSync failed: #{e.message}")
        raise Error, e.message
      end

      private

      def job_id_for!(job)
        job_id = job&.dig('job', 'id')

        raise Error, 'No job ID returned' unless job_id

        job_id
      end

      attr_reader :access_token
    end
  end
end
