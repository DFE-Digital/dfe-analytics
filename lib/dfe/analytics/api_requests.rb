# frozen_string_literal: true

module DfE
  module Analytics
    # This module provides functionality to generate api_request events through an after action controller callback
    module ApiRequests
      extend ActiveSupport::Concern

      included do
        around_action :trigger_api_request_event
      end

      include Dfe::Analytics::Concerns::Requestable

      def trigger_api_request_event
        yield # Let the request lifecycle proceed
      ensure
        trigger_request_event('api_request')
      end
    end
  end
end
