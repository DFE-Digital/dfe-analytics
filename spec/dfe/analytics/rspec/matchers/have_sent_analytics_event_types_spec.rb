# frozen_string_literal: true

require 'dfe/analytics/rspec/matchers'

class HaveSentAnalyticsEventTypesTestEvents < ActiveJob::Base
  def perform(events)
    Rails.logger.info("performing have_sent_analytics_event_types test event: #{events.inspect}")
  end
end

RSpec.describe 'have_sent_analytics_event_types matcher' do
  before do
    ActiveJob::Base.queue_adapter = :test
  end

  let(:web_request_event) { DfE::Analytics::Event.new.with_type('web_request') }
  let(:api_request_event) { DfE::Analytics::Event.new.with_type('api_request') }
  let(:update_entity_event) { DfE::Analytics::Event.new.with_type('update_entity') }

  it 'passes when the web request event type was triggered' do
    expect do
      DfE::Analytics::SendEvents.do([web_request_event.as_json])
    end.to have_sent_analytics_event_types(:web_request)
  end

  it 'passes when the api request event type was triggered' do
    expect do
      DfE::Analytics::SendEvents.do([api_request_event.as_json])
    end.to have_sent_analytics_event_types(:api_request)
  end

  it 'accepts multiple event types' do
    expect do
      DfE::Analytics::SendEvents.do([update_entity_event.as_json])
      DfE::Analytics::SendEvents.do([web_request_event.as_json])
    end.to have_sent_analytics_event_types(:web_request, :update_entity)
  end

  it 'fails if only one event type has been sent' do
    expect do
      DfE::Analytics::SendEvents.do([update_entity_event.as_json])
    end.not_to have_sent_analytics_event_types(:api_request, :web_request, :update_entity)
  end

  it 'fails when no event is triggered' do
    expect do
      nil
    end.not_to have_sent_analytics_event_types(:web_request)
  end

  it 'fails when a non analytics event is triggered' do
    expect do
      HaveSentAnalyticsEventTypesTestEvents.perform_later({})
    end.not_to have_sent_analytics_event_types(:web_request)
  end

  it 'passes if other analytics events were triggered in addition to the specified analytics type' do
    expect do
      DfE::Analytics::SendEvents.do([update_entity_event.as_json])
      DfE::Analytics::SendEvents.do([web_request_event.as_json])
    end.to have_sent_analytics_event_types(:web_request)
  end

  it 'passes if other jobs were triggered in addition to the specified analytics type' do
    expect do
      HaveSentAnalyticsEventTypesTestEvents.perform_later({})
      DfE::Analytics::SendEvents.do([web_request_event.as_json])
    end.to have_sent_analytics_event_types(:web_request)
  end

  it 'raises when not given a block' do
    expect do
      expect(nil).to have_sent_analytics_event_types(:web_request)
    end.to raise_error(ArgumentError)
  end
end
