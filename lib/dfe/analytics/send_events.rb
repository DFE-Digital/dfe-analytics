# frozen_string_literal: true

module DfE
  module Analytics
    class SendEvents < ActiveJob::Base
      queue_as { DfE::Analytics.config.queue }
      retry_on StandardError, wait: :exponentially_longer, attempts: 5

      def self.do(events)
        if DfE::Analytics.async?
          perform_later(events)
        else
          perform_now(events)
        end
      end

      def perform(events)
        if DfE::Analytics.log_only?
          Rails.logger.info("DfE::Analytics: #{events.inspect}")
        else
          DfE::Analytics.events_client.insert(events, ignore_unknown: true)
        end
      end
    end
  end
end
