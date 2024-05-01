# frozen_string_literal: true

module DfE
  module Analytics
    class SendEvents < AnalyticsJob
      def self.do(events)
        unless DfE::Analytics.enabled?
          Rails.logger.info('DfE::Analytics::SendEvents.do() called but DfE::Analytics is disabled. Please check DfE::Analytics.enabled? before sending events to BigQuery')
          return
        end

        # The initialise event is a one-off event that must be sent to BigQuery once only
        DfE::Analytics::InitialisationEvents.trigger_initialisation_events unless DfE::Analytics::InitialisationEvents.initialisation_events_sent?

        events = events.map { |event| event.is_a?(Event) ? event.as_json : event }

        if DfE::Analytics.within_maintenance_window?
          set(wait_until: DfE::Analytics.next_scheduled_time_after_maintenance_window).perform_later(events)
        elsif DfE::Analytics.async?
          perform_later(events)
        else
          perform_now(events)
        end
      end

      def perform(events)
        masked_events = events.map do |event|
          DfE::Analytics.mask_hidden_data(event, event[:entity_table_name])
        end

        if DfE::Analytics.log_only?
          # Use the Rails logger here as the job's logger is set to :warn by default
          Rails.logger.info("DfE::Analytics: #{masked_events.inspect}")
        else
          if DfE::Analytics.event_debug_enabled?
            masked_events
              .select { |event| DfE::Analytics::EventMatcher.new(event).matched? }
              .each { |event| Rails.logger.info("DfE::Analytics processing: #{event.inspect}") }
          end

          DfE::Analytics.config.azure_federated_auth ? DfE::Analytics::BigQueryApi.insert(events) : DfE::Analytics::BigQueryLegacyApi.insert(events)
        end
      end
    end
  end
end
