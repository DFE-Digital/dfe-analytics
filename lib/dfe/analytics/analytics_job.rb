module DfE
  module Analytics
    class AnalyticsJob < ActiveJob::Base
      queue_as { DfE::Analytics.config.queue }
      retry_on StandardError, wait: :polynomially_longer, attempts: 5
    end
  end
end
