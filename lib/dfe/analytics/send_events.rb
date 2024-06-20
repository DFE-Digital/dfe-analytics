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
        if DfE::Analytics.log_only?
          # Use the Rails logger here as the job's logger is set to :warn by default
          events.each { |event| Rails.logger.info("DfE::Analytics: #{mask_hidden_data(event).inspect}") }
        else
          if DfE::Analytics.event_debug_enabled?
            events
              .select { |event| DfE::Analytics::EventMatcher.new(event).matched? }
              .each { |event| Rails.logger.info("DfE::Analytics processing: #{mask_hidden_data(event).inspect}") }
          end

          DfE::Analytics.config.azure_federated_auth ? DfE::Analytics::BigQueryApi.insert(events) : DfE::Analytics::BigQueryLegacyApi.insert(events)
        end
      end

      private

      def mask_hidden_data(event)
        masked_event = duplicate_event(event)
        return event unless masked_event&.key?(:hidden_data)

        mask_hidden_data_values(masked_event)
      end

      def duplicate_event(event)
        Rails.logger.error("Event class: #{event.class}")

        case event
        when DfE::Analytics::Event
          event.event_hash.deep_dup.with_indifferent_access
        when Hash
          event.deep_dup.with_indifferent_access
        else
          Rails.logger.error("Unsupported event type: #{event.class}")
          nil
        end
      end

      def mask_hidden_data_values(event)
        hidden_data = event[:hidden_data]

        hidden_data.each { |data| mask_data(data) } if hidden_data.is_a?(Array)

        event
      end

      def mask_data(data)
        Rails.logger.error("Data class: #{data.class}")

        return unless data.is_a?(Hash)

        Rails.logger.error("Data contains value: #{data[:value]}") if data.key?(:value)
        data[:value] = ['HIDDEN'] if data[:value].present?

        unless data.key?(:key)
          Rails.logger.error('Data does not contain key')
          return
        end

        unless data[:key].is_a?(Hash)
          Rails.logger.error("Data[:key] is not a Hash: #{data[:key].class}")
          return
        end

        Rails.logger.error("Data[:key] contains value: #{data[:key][:value]}") if data[:key].key?(:value)
        data[:key][:value] = ['HIDDEN'] if data[:key][:value].present?
      end
    end
  end
end
