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
            jobs.map do |job|
              next unless job['job_class'] == 'DfE::Analytics::SendEvents'

              job[:args].first.map do |e|
                e.fetch('event_type')
              end
            end.flatten
          end
        end
      end
    end
  end
end
