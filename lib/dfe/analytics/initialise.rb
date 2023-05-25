# frozen_string_literal: true

module DfE
  module Analytics
    # DfE Analytics initialisation event
    # - Event should only be sent once, but NOT on startup as this causes errors on some services
    # - Event contains the dfe analytics version, config and other items
    class Initialise
      # Disable rubocop class variable warnings for class - class variable required to control sending of event
      # rubocop:disable Style:ClassVars
      @@initialise_event_sent = false # rubocop:disable Style:ClassVars

      def self.trigger_initialise_event
        new.send_initialise_event
      end

      def self.initialise_event_sent?
        @@initialise_event_sent
      end

      def self.initialise_event_sent=(value)
        @@initialise_event_sent = value # rubocop:disable Style:ClassVars
      end

      def send_initialise_event
        return unless DfE::Analytics.enabled?

        initialise_event = DfE::Analytics::Event.new
                                                .with_type('initialise_analytics')
                                                .with_data(initialisation_data)
                                                .as_json

        if DfE::Analytics.async?
          DfE::Analytics::SendEvents.perform_later([initialise_event])
        else
          DfE::Analytics::SendEvents.perform_now([initialise_event])
        end

        @@initialise_event_sent = true # rubocop:disable Style:ClassVars
      end

      private

      def initialisation_data
        {
          analytics_version: DfE::Analytics::VERSION,
          config: {
            pseudonymise_web_request_user_id: DfE::Analytics.config.pseudonymise_web_request_user_id
          }
        }
      end
      # rubocop:enable Style:ClassVars
    end
  end
end
