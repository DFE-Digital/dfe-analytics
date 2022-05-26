# frozen_string_literal: true

require_relative '../../../../../lib/dfe/analytics/rspec/matchers/have_sent_analytics_event'

RSpec.describe 'have_sent_analytics_event matcher' do
  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'passes when the given event type was triggered' do
    event = DfE::Analytics::Event.new.with_type('web_request')

    expect do
      DfE::Analytics::SendEvents.do([event.as_json])
    end.to have_sent_analytics_event(:web_request)
  end

  it 'detects when no event is triggered' do
    expect do
      nil
    end.not_to have_sent_analytics_event(:web_request)
  end

  it 'detects when a different event is triggered' do
    expect do
      nil
    end.not_to have_sent_analytics_event(:create_entity)
  end
end

RSpec.describe 'have_sent_request_analytics_event' do
  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'passes when the given event type was triggered' do
    event = DfE::Analytics::Event.new.with_type('web_request')

    expect do
      DfE::Analytics::SendEvents.do([event.as_json])
    end.to have_sent_request_analytics_event
  end
end

RSpec.describe 'have_sent_entity_analytics_event' do
  before do
    ActiveJob::Base.queue_adapter = :test
  end

  %w[create_entity update_entity delete_entity].each do |entity_type|
    it "passes when #{entity_type} event is triggered" do
      event = DfE::Analytics::Event.new.with_type(entity_type)

      expect do
        DfE::Analytics::SendEvents.do([event.as_json])
      end.to have_sent_entity_analytics_event
    end
  end

end
