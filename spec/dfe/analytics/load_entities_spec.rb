# frozen_string_literal: true

RSpec.describe DfE::Analytics::LoadEntities do
  before do
    allow(DfE::Analytics).to receive(:allowlist).and_return(
      {
        candidates: ['email_address']
      }
    )

    allow(DfE::Analytics).to receive(:allowlist_pii).and_return(
      {
        candidates: []
      }
    )

    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
  end

  it 'sends a model’s fields to BQ' do
    Candidate.create(email_address: 'known@address.com')

    described_class.new(model_name: 'Candidate', sleep_time: 0).run

    expect(DfE::Analytics::SendEvents).to have_received(:perform_later) do |payload|
      schema = File.read('config/event-schema.json')
      schema_validator = JSONSchemaValidator.new(schema, payload.first)

      expect(schema_validator).to be_valid, schema_validator.failure_message

      expect(payload.first['data']).to eq(
        [{ 'key' => 'email_address', 'value' => ['known@address.com'] }]
      )
    end
  end

  it 'converts arguments values' do
    Candidate.create
    Candidate.create

    described_class.new(model_name: 'Candidate', batch_size: '1', sleep_time: '0').run

    expect(DfE::Analytics::SendEvents).to have_received(:perform_later).twice
  end

  it 'can work in batches' do
    Candidate.create
    Candidate.create

    described_class.new(model_name: 'Candidate', batch_size: 1, sleep_time: 0).run

    expect(DfE::Analytics::SendEvents).to have_received(:perform_later).twice
  end

  it 'can start from an id' do
    Candidate.create
    Candidate.create
    highest_id = Candidate.maximum(:id)

    described_class.new(model_name: 'Candidate', batch_size: 1, sleep_time: 0, start_at_id: highest_id).run

    expect(DfE::Analytics::SendEvents).to have_received(:perform_later).once
  end
end
