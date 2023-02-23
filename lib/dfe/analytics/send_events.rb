# frozen_string_literal: true

module DfE
  module Analytics
    class SendEvents < AnalyticsJob
      def self.do(events)
        events = events.map { |event| event.is_a?(Event) ? event.as_json : event }

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

          if DfE::Analytics.event_debug_enabled?
            events
              .select { |event| DfE::Analytics::EventMatcher.new(event).matched? }
              .each { |event| Rails.logger.info("DfE::Analytics processing: #{event.inspect}") }
          end

          response = DfE::Analytics.events_client.insert(events, ignore_unknown: true)

          unless response.success?
            error_message = error_message_for(response.insert_errors)

            Rails.logger.error(error_message)

            raise SendEventsError, error_message
          end
        end
      end

      def error_message_for(insert_errors)
        message = insert_errors
          .flat_map(&:errors)
          .map { |error| error.try(:message) || error['message'] }
          .compact.join("\n")

        "Could not insert all events:\n#{message}"
      end
    end

    class SendEventsError < StandardError
    end
  end
end
