# frozen_string_literal: true

require 'dfe/analytics/rspec/matchers'

class HaveBeenEnqueuedAsAnalyticsEventsTestEvents < ActiveJob::Base
  def perform(events)
    Rails.logger.info("performing have_been_enqueued_as_analytics_events test event: #{events.inspect}")
  end
end

RSpec.describe 'have_been_enqueued_as_analytics_events matcher' do
  before do
    ActiveJob::Base.queue_adapter = :test
  end

  let(:web_request_event) { DfE::Analytics::Event.new.with_type('web_request') }
  let(:api_request_event) { DfE::Analytics::Event.new.with_type('api_request') }
  let(:update_entity_event) { DfE::Analytics::Event.new.with_type('update_entity') }

  it 'passes when the web request event type was triggered' do
    DfE::Analytics::SendEvents.do([web_request_event.as_json])

    expect(:web_request).to have_been_enqueued_as_analytics_events
  end

  it 'passes when the api request event type was triggered' do
    DfE::Analytics::SendEvents.do([api_request_event.as_json])

    expect(:api_request).to have_been_enqueued_as_analytics_events
  end

  it 'accepts multiple event types' do
    DfE::Analytics::SendEvents.do([web_request_event.as_json])
    DfE::Analytics::SendEvents.do([update_entity_event.as_json])

    expect(%i[web_request update_entity]).to have_been_enqueued_as_analytics_events
  end

  it 'fails if only one event type has been sent' do
    DfE::Analytics::SendEvents.do([web_request_event.as_json])

    expect(%i[web_request update_entity]).not_to have_been_enqueued_as_analytics_events
  end

  it 'fails when no event is triggered' do
    expect(:web_request).not_to have_been_enqueued_as_analytics_events
  end

  it 'fails when a non analytics event is triggered' do
    HaveBeenEnqueuedAsAnalyticsEventsTestEvents.perform_later({})

    expect(HaveBeenEnqueuedAsAnalyticsEventsTestEvents).to have_been_enqueued
    expect(:web_request).not_to have_been_enqueued_as_analytics_events
  end

  it 'passes if other analytics events were triggered in addition to the specified analytics type' do
    DfE::Analytics::SendEvents.do([update_entity_event.as_json])
    DfE::Analytics::SendEvents.do([web_request_event.as_json])
    DfE::Analytics::SendEvents.do([api_request_event.as_json])

    expect(:update_entity).to have_been_enqueued_as_analytics_events
    expect(:web_request).to have_been_enqueued_as_analytics_events
    expect(:api_request).to have_been_enqueued_as_analytics_events
  end

  it 'passes if other jobs were triggered in addition to the specified analytics type' do
    HaveBeenEnqueuedAsAnalyticsEventsTestEvents.perform_later({})
    DfE::Analytics::SendEvents.do([web_request_event.as_json])

    expect(HaveBeenEnqueuedAsAnalyticsEventsTestEvents).to have_been_enqueued
    expect(:web_request).to have_been_enqueued_as_analytics_events
  end
end
