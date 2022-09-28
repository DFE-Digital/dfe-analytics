# frozen_string_literal: true

RSpec.describe DfE::Analytics::LoadEntities do
  include ActiveJob::TestHelper

  with_model :Candidate do
    table do |t|
      t.string :email_address
    end
  end

  with_model :ModelWithCustomPrimaryKey do
    table id: false do |t|
      t.string :custom_key
    end

    model do |m|
      m.primary_key = :custom_key
    end
  end

  before do
    allow(DfE::Analytics).to receive(:allowlist).and_return({
      Candidate.table_name.to_sym => ['email_address']
    })

    allow(DfE::Analytics).to receive(:allowlist_pii).and_return({
      Candidate.table_name.to_sym => []
    })

    # autogenerate a compliant blocklist
    allow(DfE::Analytics).to receive(:blocklist).and_return(DfE::Analytics::Fields.generate_blocklist)

    allow(DfE::Analytics::SendEvents).to receive(:perform_now)

    allow(Rails.logger).to receive(:info)

    DfE::Analytics.initialize!
  end

  around do |ex|
    perform_enqueued_jobs do
      ex.run
    end
  end

  it 'sends a entity’s fields to BQ' do
    Candidate.create(email_address: 'known@address.com')

    described_class.new(entity_name: Candidate.table_name).run

    # import process
    expect(DfE::Analytics::SendEvents).to have_received(:perform_now).once do |payload|
      schema = DfE::Analytics::EventSchema.new.as_json
      schema_validator = JSONSchemaValidator.new(schema, payload.first)

      expect(schema_validator).to be_valid, schema_validator.failure_message

      expect(payload.first['data']).to eq(
        [{ 'key' => 'email_address', 'value' => ['known@address.com'] }]
      )
    end
  end

  it 'can work in batches' do
    stub_const('DfE::Analytics::LoadEntities::BQ_BATCH_ROWS', 2)

    3.times { Candidate.create }

    described_class.new(entity_name: Candidate.table_name).run

    expect(DfE::Analytics::SendEvents).to have_received(:perform_now).exactly(2).times
  end

  it 'does not fail with models whose primary key is not :id' do
    ModelWithCustomPrimaryKey.create

    expect { described_class.new(entity_name: ModelWithCustomPrimaryKey.table_name).run }.not_to raise_error
    expect(Rails.logger).to have_received(:info).with(/we do not support non-id primary keys/)
  end
end
