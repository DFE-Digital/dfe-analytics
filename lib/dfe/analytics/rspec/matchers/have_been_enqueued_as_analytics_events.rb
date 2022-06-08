# frozen_string_literal: true

require_relative './helpers'

RSpec::Matchers.define :have_been_enqueued_as_analytics_events do
  include DfE::Analytics::RSpec::Matchers::Helpers

  match do |event_types|
    Array(event_types).each do |event_type|
      expect(enqueued_event_types).to include(event_type.to_s)
    end
  end

  failure_message do |event_types|
    if enqueued_event_types.blank?
      "expected #{Array(event_types).map(&:to_s)} to have been sent as an analytics event type, but no analytics events were sent"
    else
      "expected #{Array(event_types).map(&:to_s)} to have been sent as an analytics event type, but found event types: #{enqueued_event_types.uniq}"
    end
  end

  def enqueued_event_types
    @enqueued_event_types ||= jobs_to_event_types(queue_adapter.enqueued_jobs)
  end
end
