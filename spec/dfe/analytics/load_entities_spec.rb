# frozen_string_literal: true

RSpec.describe DfE::Analytics::LoadEntities do
  include ActiveJob::TestHelper

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

  around do |ex|
    perform_enqueued_jobs do
      ex.run
    end
  end

  it 'sends a entity’s fields to BQ' do
    Candidate.create(email_address: 'known@address.com')

    described_class.new(entity_name: 'candidates').run

    expect(DfE::Analytics::SendEvents).to have_received(:perform_later) do |payload|
      schema = DfE::Analytics::EventSchema.new.as_json
      schema_validator = JSONSchemaValidator.new(schema, payload.first)

      expect(schema_validator).to be_valid, schema_validator.failure_message

      expect(payload.first['data']).to eq(
        [{ 'key' => 'email_address', 'value' => ['known@address.com'] }]
      )
    end
  end

  it 'can work in batches' do
    Candidate.create
    Candidate.create

    described_class.new(entity_name: 'candidates', batch_size: 2).run

    expect(DfE::Analytics::SendEvents).to have_received(:perform_later).once
  end
end
