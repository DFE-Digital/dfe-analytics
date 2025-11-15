# frozen_string_literal: true

module DfE
  module Analytics
    # Orchestration job for airbyte deployment
    class AirbyteDeployJob < AnalyticsJob
      queue_as :default
      # No retries – discard on any StandardError
      discard_on StandardError

      def perform
        # Wait for any pending migrationsto finish
        DfE::Analytics::Services::WaitForMigrations.call

        access_token = ::Services::Airbyte::AccessToken.call
        connection_id, source_id = ::Services::Airbyte::ConnectionList.call(access_token:)

        # Refresh schema
        ::Services::Airbyte::ConnectionRefresh.call(access_token:, connection_id:, source_id:)

        # Check if a sync job is already running
        last_job = ::Services::Airbyte::JobLast.call(access_token:, connection_id:)
        status = last_job&.dig('status')
        job_id = last_job&.dig('id')

        job_id = ::Services::Airbyte::StartSync.call(access_token:, connection_id:) if status != 'running'

        # Wait for the job (existing or new) to finish
        ::Services::Airbyte::WaitForSync.call(access_token:, connection_id:, job_id:)

        # Trigger policy tagging
        BigQueryApplyPolicyTagsJob.perform_later
      rescue StandardError => e
        Rails.logger.error(e.message)
        raise "AirbyteDeployJob failed: #{e.message}"
      end
    end
  end
end
