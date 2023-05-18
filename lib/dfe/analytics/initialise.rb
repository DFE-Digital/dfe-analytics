# frozen_string_literal: true

module DfE
  module Analytics
    # Send event on dfe analytics startup during initialisation
    # - Event contains the dfe analytics version, config and other items
    class Initialise
      def self.trigger_initialise_event
        new.send_initialise_event
      end

      def send_initialise_event
        return unless DfE::Analytics.enabled?

        initialise_event = DfE::Analytics::Event.new
                                              .with_type('analytics_initialise')
                                              .with_data(initialise_data)

        DfE::Analytics::SendEvents.do([initialise_event.as_json])
      end

      private

      def initialise_data
        {
          analytics_version: DfE::Analytics::VERSION,
          config: {
            anonymise_web_request_user_id: DfE::Analytics.config.anonymise_web_request_user_id
          }
        }
      end
    end
  end
end
