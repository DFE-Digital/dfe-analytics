# frozen_string_literal: true

require_relative '../../../../../lib/dfe/analytics/rspec/matchers'

class HaveBeenEnqueuedEventTypesTestEvents < ActiveJob::Base
  def perform(events)
    Rails.logger.info("performing have_been_enqueued_event_types test event: #{events.inspect}")
  end
end

RSpec.describe 'have_been_enqueued_event_types matcher' do
  before do
    ActiveJob::Base.queue_adapter = :test
  end

  let(:web_request_event) { DfE::Analytics::Event.new.with_type('web_request') }
  let(:update_entity_event) { DfE::Analytics::Event.new.with_type('update_entity') }

  it 'passes when the given event type was triggered' do
    DfE::Analytics::SendEvents.do([web_request_event.as_json])

    expect(:web_request).to have_been_enqueued_event_types
  end

  it 'accepts multiple event types' do
    DfE::Analytics::SendEvents.do([web_request_event.as_json])
    DfE::Analytics::SendEvents.do([update_entity_event.as_json])

    expect(%i[web_request update_entity]).to have_been_enqueued_event_types
  end

  it 'fails if only one event type has been sent' do
    DfE::Analytics::SendEvents.do([web_request_event.as_json])

    expect(%i[web_request update_entity]).not_to have_been_enqueued_event_types
  end

  it 'fails when no event is triggered' do
    expect(:web_request).not_to have_been_enqueued_event_types
  end

  it 'fails when a non analytics event is triggered' do
    HaveBeenEnqueuedEventTypesTestEvents.perform_later({})

    expect(HaveBeenEnqueuedEventTypesTestEvents).to have_been_enqueued
    expect(:web_request).not_to have_been_enqueued_event_types
  end

  it 'passes if other analytics events were triggered in addition to the specified analytics type' do
    DfE::Analytics::SendEvents.do([update_entity_event.as_json])
    DfE::Analytics::SendEvents.do([web_request_event.as_json])

    expect(:update_entity).to have_been_enqueued_event_types
    expect(:web_request).to have_been_enqueued_event_types
  end

  it 'passes if other jobs were triggered in addition to the specified analytics type' do
    HaveBeenEnqueuedEventTypesTestEvents.perform_later({})
    DfE::Analytics::SendEvents.do([web_request_event.as_json])

    expect(HaveBeenEnqueuedEventTypesTestEvents).to have_been_enqueued
    expect(:web_request).to have_been_enqueued_event_types
  end
end
