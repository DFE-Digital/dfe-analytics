# frozen_string_literal: true

module DfE
  module Analytics
    class SendEvents < AnalyticsJob
      def self.do(events)
        # The initialise event is a one-off event that must be sent to BigQuery once only

        DfE::Analytics::InitialisationEvents.trigger_initialisation_events unless DfE::Analytics::InitialisationEvents.initialisation_events_sent?

        events = events.map { |event| event.is_a?(Event) ? event.as_json : event }

        if DfE::Analytics.async?
          perform_later(events)
        else
          perform_now(events)
        end
      end

      def perform(events)
        if DfE::Analytics.within_maintenance_window?
          # Delaying / Queueing events - the redis bit
          Rails.logger.info('Within BigQuery maintenance window. Events will be queued for later processing.')
          return
        end

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
            event_count   = events.length
            error_message = error_message_for(response)

            Rails.logger.error(error_message)

            events.each.with_index(1) do |event, index|
              Rails.logger.info("DfE::Analytics possible error processing event (#{index}/#{event_count}): #{event.inspect}")
            end

            raise SendEventsError, error_message
          end
        end
      end

      def error_message_for(resp)
        message =
          resp
          .error_rows
          .map { |row| "index: #{resp.index_for(row)} error: #{resp.errors_for(row)} error_row: #{row}" }
          .compact.join("\n")

        "DfE::Analytics BigQuery API insert error for #{resp.error_rows.length} event(s): response error count: #{resp.error_count}\n#{message}"
      end
    end

    class SendEventsError < StandardError
    end
  end
end
