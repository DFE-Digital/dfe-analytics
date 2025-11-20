# frozen_string_literal: true

module Services
  module Airbyte
    # Looks up a specific job's status by scanning the recent Airbyte jobs list.
    #
    # Why this scans multiple jobs (PAGE_SIZE = 10):
    # /api/v1/jobs/get often requires admin privileges, so we query /api/v1/jobs/list
    # and search for our job_id. The tracked job might not be the most recent,
    # hence PAGE_SIZE = 10 for safety.
    class JobStatus
      class Error < StandardError; end

      PAGE_SIZE = 10 # Number of recent jobs to fetch when searching for a job_id

      def self.call(access_token:, connection_id:, job_id:)
        new(access_token:, connection_id:, job_id:).call
      end

      def initialize(access_token:, connection_id:, job_id:)
        @access_token = access_token
        @connection_id = connection_id
        @job_id = job_id
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

        jobs = response['jobs'] || []
        job = jobs.find { |j| j.dig('job', 'id') == @job_id }

        raise Error, "Job #{@job_id} not found in the last #{PAGE_SIZE} jobs" unless job

        job.dig('job', 'status')
      rescue StandardError => e
        Rails.logger.error(e.message)
        raise Error, e.message
      end
    end
  end
end
