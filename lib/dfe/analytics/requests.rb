# frozen_string_literal: true

module DfE
  module Analytics
    # This module provides functionality to generate web_request events through an after action controller callback
    module Requests
      extend ActiveSupport::Concern

      included do
        after_action :trigger_web_request_event
      end

      include Dfe::Analytics::Concerns::Requestable

      def trigger_web_request_event
        trigger_request_event('web_request')
      end
    end
  end
end
