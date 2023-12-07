module DfE
  module Analytics
    class AnalyticsJob < ActiveJob::Base
      queue_as { DfE::Analytics.config.queue }

      wait_option = Rails::VERSION::STRING >= '7.1' ? :polynomially_longer : :exponentially_longer
      retry_on StandardError, wait: wait_option, attempts: 5
    end
  end
end
