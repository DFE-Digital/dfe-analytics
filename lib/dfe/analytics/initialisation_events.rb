# frozen_string_literal: true

module DfE
  module Analytics
    # DfE Analytics initialisation events
    # - Event should only be sent once, but NOT on startup as this causes errors on some services
    # - Event contains the dfe analytics version, config and other items
    class InitialisationEvents
      # Disable rubocop class variable warnings for class - class variable required to control sending of event
      # rubocop:disable Style/ClassVars
      @@initialisation_events_sent = false # rubocop:disable Style/ClassVars

      def self.trigger_initialisation_events
        new.send_initialisation_events
      end

      def self.initialisation_events_sent?
        @@initialisation_events_sent
      end

      def self.initialisation_events_sent=(value)
        @@initialisation_events_sent = value # rubocop:disable Style/ClassVars
      end

      def send_initialisation_events
        return unless DfE::Analytics.enabled?

        initialise_analytics_event = DfE::Analytics::Event.new
                                                .with_type('initialise_analytics')
                                                .with_data(data: initialise_analytics_data)
                                                .as_json

        DfE::Analytics::SendEvents.perform_for([initialise_analytics_event])

        @@initialisation_events_sent = true # rubocop:disable Style/ClassVars
      end

      private

      def initialise_analytics_data
        {
          analytics_version: DfE::Analytics::VERSION,
          config: {
            entity_table_checks_enabled: DfE::Analytics.config.entity_table_checks_enabled
          }
        }
      end
      # rubocop:enable Style/ClassVars
    end
  end
end
