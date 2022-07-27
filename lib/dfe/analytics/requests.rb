# frozen_string_literal: true

module DfE
  module Analytics
    module Requests
      extend ActiveSupport::Concern

      included do
        after_action :trigger_request_event
      end

      def trigger_request_event
        return unless DfE::Analytics.enabled?

        request_event = DfE::Analytics::Event.new
                                             .with_type('web_request')
                                             .with_request_details(request)
                                             .with_response_details(response)
                                             .with_request_uuid(RequestLocals.fetch(:dfe_analytics_request_id) { nil })

        request_event.with_user(current_user)           if respond_to?(:current_user, true)
        request_event.with_namespace(current_namespace) if respond_to?(:current_namespace, true)

        DfE::Analytics::SendEvents.do([request_event.as_json])
      end
    end
  end
end
