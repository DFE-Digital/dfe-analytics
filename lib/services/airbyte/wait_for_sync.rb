# frozen_string_literal: true

module Services
  module Airbyte
    # Polls Airbyte until a sync job finishes or times out
    class WaitForSync
      class Error < StandardError; end

      WAIT_INTERVAL = 30        # seconds
      TIMEOUT_SECONDS = 3600    # 1 hour

      def self.call(access_token:, connection_id:, job_id:)
        new(access_token:, connection_id:, job_id:).call
      end

      def initialize(access_token:, connection_id:, job_id:)
        @access_token = access_token
        @connection_id = connection_id
        @job_id = job_id
      end

      def call
        start_time = Time.now

        loop do
          status = Services::Airbyte::JobStatus.call(
            access_token: @access_token,
            connection_id: @connection_id,
            job_id: @job_id
          )

          case status
          when 'succeeded'
            return 'succeeded'
          when 'failed', 'cancelled', 'error'
            raise Error, "Airbyte sync job #{@job_id} failed with status: #{status}"
          end

          raise Error, "Timed out waiting for Airbyte sync job #{@job_id}" if Time.now - start_time > TIMEOUT_SECONDS

          sleep WAIT_INTERVAL
        end
      end
    end
  end
end
