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

        perform_for(events)
      end

      def self.perform_for(events)
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
          Rails.logger.info("DfE::Analytics: #{obscure_hidden_data(events).inspect}")
        else

          if DfE::Analytics.event_debug_enabled?
            events
              .select { |event| DfE::Analytics::EventMatcher.new(event).matched? }
              .each { |event| Rails.logger.info("DfE::Analytics processing: #{obscure_hidden_data([event]).first.inspect}") }
          end

          DfE::Analytics.config.azure_federated_auth ? DfE::Analytics::BigQueryApi.insert(events) : DfE::Analytics::BigQueryLegacyApi.insert(events)
        end
      end

      private

      def obscure_hidden_data(events)
        events.map do |event|
          obscure_event_hidden_data(event)
        end
      end

      def obscure_event_hidden_data(event)
        if event.is_a?(Hash)
          event.deep_dup.tap do |e|
            if e.key?('hidden_data')
              e['hidden_data'] = e['hidden_data'].map do |data|
                data_value = data['value'].nil? ? 'HIDDEN' : ['HIDDEN']
                data.merge('value' => data_value)
              end
            end
          end
        else
          event
        end
      end
    end
  end
end
