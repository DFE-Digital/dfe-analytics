# frozen_string_literal: true

RSpec::Matchers.define :have_sent_analytics_event do |*event_types|
  match do |actual|
    expect do
      actual.call
    end.to(
      have_enqueued_job(DfE::Analytics::SendEvents).with do |events|
        @enqueued_event_types = events.collect { |e| e['event_type'] }
        matched_event_types = @enqueued_event_types & event_types.map(&:to_s)
        expect(matched_event_types).not_to be_empty
      end
    )
  end

  failure_message do |actual|
    if @enqueued_event_types.blank?
      "expected #{RSpec::Support::ObjectFormatter.format(actual)} to have sent one of #{event_types.map(&:to_s)} analytics event, but no analytics events were sent"
    else
      "expected #{RSpec::Support::ObjectFormatter.format(actual)} to have sent one of #{event_types.map(&:to_s)} analytics event, but found event types: #{@enqueued_event_types.uniq}"
    end
  end

  supports_block_expectations
end

def have_sent_request_analytics_event
  have_sent_analytics_event(:web_request)
end

def have_sent_entity_analytics_event
  have_sent_analytics_event(:create_entity, :update_entity, :delete_entity)
end
