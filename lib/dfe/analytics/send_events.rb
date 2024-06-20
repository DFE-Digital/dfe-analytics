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
      rescue StandardError => e
        Rails.logger.error("Error in SendEvents.do: #{e.message}")
        raise e
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
      rescue StandardError => e
        Rails.logger.error("Error in SendEvents#perform: #{e.message}")
        raise e
      end

      private

      def mask_hidden_data(event)
        Rails.logger.debug("Masking hidden data for event: #{event.inspect}")

        if event.is_a?(DfE::Analytics::Event)
          masked_event = event.event_hash.deep_dup.with_indifferent_access
        elsif event.is_a?(Hash)
          masked_event = event.deep_dup.with_indifferent_access
        else
          Rails.logger.info("Event is neither a DfE::Analytics::Event nor a Hash: #{event.inspect}")
          return event
        end

        unless masked_event.key?(:hidden_data)
          Rails.logger.info("No hidden_data key found in event: #{masked_event.inspect}")
          return masked_event
        end

        hidden_data = masked_event[:hidden_data]

        if hidden_data.is_a?(Array)
          hidden_data.each do |data|
            next unless data.is_a?(Hash)

            data[:value] = ['HIDDEN'] if data[:value]

            data[:key][:value] = ['HIDDEN'] if data[:key].is_a?(Hash) && data[:key][:value]
          end
        else
          Rails.logger.info("Unexpected hidden_data structure: expected Array, got #{hidden_data.class}")
        end

        Rails.logger.info("Masked event: #{masked_event.inspect}")
        masked_event
      rescue StandardError => e
        Rails.logger.error("Error in SendEvents#mask_hidden_data: #{e.message}")
        Rails.logger.error("Event causing error: #{event.inspect}")
        raise e
      end
    end
  end
end
