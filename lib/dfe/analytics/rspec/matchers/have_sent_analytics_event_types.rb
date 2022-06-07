# frozen_string_literal: true

require_relative './helpers'

RSpec::Matchers.define :have_sent_analytics_event_types do |*event_types|
  include DfE::Analytics::RSpec::Matchers::Helpers

  supports_block_expectations

  match do |proc|
    raise ArgumentError, 'have_sent_analytics_event_types only supports block expectations' unless Proc === proc # rubocop:disable Style/CaseEquality

    original_enqueued_jobs_count = queue_adapter.enqueued_jobs.count
    actual.call
    in_block_jobs = queue_adapter.enqueued_jobs.drop(original_enqueued_jobs_count)

    @enqueued_event_types = jobs_to_event_types(in_block_jobs)

    Array(event_types).each do |event_type|
      expect(@enqueued_event_types).to include(event_type.to_s)
    end
    # expect(event_types.map(&:to_s) & @enqueued_event_types).not_to be_blank
  end

  failure_message do |actual|
    if @enqueued_event_types.blank?
      "expected #{RSpec::Support::ObjectFormatter.format(actual)} to have sent one of #{Array(event_types).map(&:to_s)} analytics event, but no analytics events were sent"
    else
      "expected #{RSpec::Support::ObjectFormatter.format(actual)} to have sent one of #{Array(event_types).map(&:to_s)} analytics event, but found event types: #{@enqueued_event_types.uniq}"
    end
  end
end
