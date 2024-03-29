# frozen_string_literal: true

RSpec.describe DfE::Analytics::InitialisationEvents do
  before do
    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
    allow(DfE::Analytics.config).to receive(:entity_table_checks_enabled).and_return(true)
    allow(DfE::Analytics).to receive(:enabled?).and_return(true)
    described_class.trigger_initialisation_events
  end

  describe 'trigger_initialisation_events ' do
    it 'includes the expected attributes' do
      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'event_type' => 'initialise_analytics',
          'data' => [
            { 'key' => 'analytics_version', 'value' => [DfE::Analytics::VERSION] },
            { 'key' => 'config',
              'value' => ['{"pseudonymise_web_request_user_id":false,"entity_table_checks_enabled":true}'] }
          ]
        })])
    end
  end

  describe '.initialisation_events_sent=' do
    it 'allows setting of the class variable' do
      described_class.initialisation_events_sent = true
      expect(described_class.initialisation_events_sent?).to eq(true)
    end
  end
end
