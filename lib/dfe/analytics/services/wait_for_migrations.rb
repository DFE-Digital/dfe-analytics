# frozen_string_literal: true

module DfE
  module Analytics
    module Services
      # Polls for pending migrations and waits until they are cleared or times out
      class WaitForMigrations
        class Error < StandardError; end

        WAIT_INTERVAL = 30        # seconds
        TIMEOUT_SECONDS = 600     # 10 minutes

        def self.call
          new.call
        end

        def call
          start_time = Time.now

          loop do
            raise Error, 'Timed out waiting for pending migrations to clear' if Time.now - start_time > TIMEOUT_SECONDS

            sleep WAIT_INTERVAL
            break unless pending_migrations?
          end
        rescue StandardError => e
          raise Error, e.message
        end

        private

        def pending_migrations?
          ActiveRecord::Migration.check_all_pending!
        rescue ActiveRecord::PendingMigrationError
          true
        rescue StandardError => e
          Rails.logger.error("Error checking migration status: #{e.message}")

          raise Error, "Could not check migration status: #{e.message}"
        end
      end
    end
  end
end
