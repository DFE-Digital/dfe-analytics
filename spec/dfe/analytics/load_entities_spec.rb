# frozen_string_literal: true

RSpec.describe DfE::Analytics::LoadEntities do
  include ActiveJob::TestHelper

  with_model :Candidate do
    table do |t|
      t.string :email_address
    end
  end

  with_model :CandidateWithDefaultScope do
    table do |t|
      t.string  :email_address
      t.boolean :active, default: true, null: false
    end

    model do
      default_scope { where(active: true) }
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

  with_model :ModelWithoutPrimaryKey do
    table id: false do |t|
      t.string :custom_key
    end

    model do |m|
      m.primary_key = nil
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

    DfE::Analytics::Testing.fake!
  end

  around do |ex|
    perform_enqueued_jobs do
      ex.run
    end
  end

  let(:entity_tag) { '20230101123000' }

  it 'sends an entity’s fields to BQ' do
    Candidate.create(email_address: 'known@address.com')
    described_class.new(entity_name: Candidate.table_name).run(entity_tag: entity_tag)

    # import process
    expect(DfE::Analytics::SendEvents).to have_received(:perform_now).once do |payload|
      schema = DfE::Analytics::EventSchema.new.as_json
      schema_validator = JSONSchemaValidator.new(schema, payload.first)

      expect(schema_validator).to be_valid, schema_validator.failure_message

      expect(payload.first['data']).to include(
        a_hash_including('key' => 'email_address', 'value' => include('known@address.com'))
      )
    end
  end

  it 'can work in batches' do
    stub_const('DfE::Analytics::LoadEntities::BQ_BATCH_ROWS', 2)

    3.times { Candidate.create }

    described_class.new(entity_name: Candidate.table_name).run(entity_tag: entity_tag)

    expect(DfE::Analytics::SendEvents).to have_received(:perform_now).exactly(2).times
  end

  it 'does not fail with models whose primary key is not :id' do
    ModelWithCustomPrimaryKey.create

    expect { described_class.new(entity_name: ModelWithCustomPrimaryKey.table_name).run(entity_tag: entity_tag) }.not_to raise_error
    expect(Rails.logger).to have_received(:info).with(/we do not support non-id primary keys/)
  end

  it 'does not fail with models whose primary key is nil' do
    ModelWithoutPrimaryKey.create

    expect { described_class.new(entity_name: ModelWithoutPrimaryKey.table_name).run(entity_tag: entity_tag) }.not_to raise_error
    expect(Rails.logger).to have_received(:info).with(/Not processing #{ModelWithoutPrimaryKey.table_name} as it does not have a primary key/)
  end

  describe 'ignore_default_scope behaviour' do
    before do
      stub_const('DfE::Analytics::LoadEntities::BQ_BATCH_ROWS', 1)

      CandidateWithDefaultScope.create!(email_address: 'active@example.com',   active: true)
      CandidateWithDefaultScope.create!(email_address: 'inactive@example.com', active: false)
    end

    it 'respects the default scope when ignore_default_scope is false' do
      allow(DfE::Analytics.config).to receive(:ignore_default_scope).and_return(false)

      described_class.new(entity_name: CandidateWithDefaultScope.table_name).run(entity_tag: entity_tag)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_now).exactly(1).time
    end

    it 'processes unscoped records when ignore_default_scope is true' do
      allow(DfE::Analytics.config).to receive(:ignore_default_scope).and_return(true)

      described_class.new(entity_name: CandidateWithDefaultScope.table_name).run(entity_tag: entity_tag)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_now).exactly(2).times
    end
  end
end
