# frozen_string_literal: true

module DfE
  module Analytics
    class SendEvents < AnalyticsJob
      def self.do(events)
        if DfE::Analytics.async?
          perform_later(events)
        else
          perform_now(events)
        end
      end

      def perform(events)
        if DfE::Analytics.log_only?
          # Use the Rails logger here as the job's logger is set to :warn by default
          Rails.logger.info("DfE::Analytics: #{events.inspect}")
        else
          response = DfE::Analytics.events_client.insert(events, ignore_unknown: true)
          raise SendEventsError, response.insert_errors unless response.success?
        end
      end
    end

    class SendEventsError < StandardError
      attr_reader :insert_errors

      def initialize(insert_errors)
        @insert_errors = insert_errors

        message = insert_errors
          .flat_map(&:errors)
          .map { |error| error.try(:message) || error['message'] }
          .compact.join("\n")

        super("Could not insert all events:\n#{message}")
      end
    end
  end
end
