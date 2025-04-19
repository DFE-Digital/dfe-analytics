# frozen_string_literal: true

module Dfe
  module Analytics
    module Concerns
      # This module provides common functionality to generate request events for the given event type
      module Requestable
        def trigger_request_event(event_type)
          return unless DfE::Analytics.enabled?
          return if path_excluded?

          request_event = DfE::Analytics::Event.new
                                               .with_type(event_type)
                                               .with_request_details(request)
                                               .with_response_details(response)
                                               .with_request_uuid(RequestLocals.fetch(:dfe_analytics_request_id) { nil })

          request_event.with_user(current_user)           if respond_to?(:current_user, true)
          request_event.with_namespace(current_namespace) if respond_to?(:current_namespace, true)

          DfE::Analytics::SendEvents.do([request_event.as_json])
        end

        private

        def path_excluded?
          excluded_path = DfE::Analytics.config.excluded_paths
          excluded_path.any? do |path|
            if path.is_a?(Regexp)
              path.match?(request.fullpath)
            else
              request.fullpath.start_with?(path)
            end
          end
        end
      end
    end
  end
end
