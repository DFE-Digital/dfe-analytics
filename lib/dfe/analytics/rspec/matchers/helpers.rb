# lib/helpers.rb

module DfE
  module Analytics
    module RSpec
      module Matchers
        # Helpers for matchers in this package.
        module Helpers
          def queue_adapter
            ::ActiveJob::Base.queue_adapter
          end

          def jobs_to_event_types(jobs)
            jobs.map do |j|
              j[:args].first.map do |e|
                e.fetch('event_type')
              end
            rescue StandardError
              # Parsing the job args above makes a couple of assumptions that may
              # raise an error. Treat these as non-analytics events by returning
              # 'nil' for the type.
              nil
            end.flatten
          end
        end
      end
    end
  end
end
