# frozen_string_literal: true

RSpec.describe DfE::Analytics::Initialise do
  before do
    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
    allow(DfE::Analytics).to receive(:enabled?).and_return(true)
  end

  describe 'trigger_initialise_event ' do
    it 'includes the expected attributes' do
      described_class.trigger_initialise_event

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'event_type' => 'initialise_analytics',
          'data' => [
            { 'key' => 'analytics_version', 'value' => [DfE::Analytics::VERSION] },
            { 'key' => 'config',
              'value' => ['{"pseudonymise_web_request_user_id":false}'] }
          ]
        })])
    end
  end

  describe '.initialise_event_sent=' do
    it 'allows setting of the class variable' do
      described_class.initialise_event_sent = true
      expect(described_class.initialise_event_sent?).to eq(true)
    end
  end
end
