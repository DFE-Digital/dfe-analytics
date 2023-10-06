# frozen_string_literal: true

RSpec.describe DfE::Analytics::Entities do
  let(:interesting_fields) { [] }
  let(:pii_fields) { [] }

  with_model :Candidate do
    table do |t|
      t.string :type
      t.string :email_address
      t.string :last_name
      t.string :first_name
      t.string :user_id
      t.boolean :degree
    end
  end

  before do
    stub_const('Teacher', Class.new(Candidate))
    stub_const('Assistant', Class.new(Candidate))
    Teacher.ignored_columns = %w[user_id]
    Assistant.ignored_columns = %w[user_id degree]
    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
    allow(DfE::Analytics).to receive(:enabled?).and_return(true)

    allow(DfE::Analytics).to receive(:allowlist).and_return({
      Candidate.table_name.to_sym => interesting_fields
    })

    allow(DfE::Analytics).to receive(:allowlist_pii).and_return({
      Candidate.table_name.to_sym => pii_fields
    })

    # autogenerate a compliant blocklist
    allow(DfE::Analytics).to receive(:blocklist).and_return(DfE::Analytics::Fields.generate_blocklist)

    DfE::Analytics.initialize!
  end

  describe 'create_entity events' do
    context 'when fields are specified in the analytics file' do
      let(:interesting_fields) { ['id'] }

      it 'includes attributes specified in the settings file' do
        Candidate.create(id: 123)

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'entity_table_name' => Candidate.table_name,
            'event_type' => 'create_entity',
            'data' => [
              { 'key' => 'id', 'value' => [123] }
            ]
          })])
      end

      it 'does not include attributes not specified in the settings file' do
        Candidate.create(id: 123, email_address: 'a@b.com')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'entity_table_name' => Candidate.table_name,
            'event_type' => 'create_entity',
            'data' => [
              { 'key' => 'id', 'value' => [123] }
              # ie the same payload as above
            ]
          })])
      end

      it 'sends events that are valid according to the schema' do
        Candidate.create

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later).once do |payload|
          schema = DfE::Analytics::EventSchema.new.as_json
          schema_validator = JSONSchemaValidator.new(schema, payload.first)

          expect(schema_validator).to be_valid, schema_validator.failure_message
        end
      end

      it 'sends events with the request UUID, if available' do
        RequestLocals.store[:dfe_analytics_request_id] = 'example-request-id'

        Candidate.create

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'request_uuid' => 'example-request-id'
          })])
      end

      context 'and the specified fields are listed as PII' do
        let(:interesting_fields) { ['email_address'] }
        let(:pii_fields) { ['email_address'] }

        it 'hashes those fields' do
          Candidate.create(email_address: 'adrienne@example.com')

          expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
            .with([a_hash_including({
              'data' => [
                { 'key' => 'email_address',
                  'value' => ['928b126cb77de8a61bf6714b4f6b0147be7f9d5eb60158930c34ef70f4d502d6'] }
              ]
            })])
        end
      end

      context 'and other fields are listed as PII' do
        let(:interesting_fields) { ['id'] }
        let(:pii_fields) { ['email_address'] }

        it 'does not include the fields only listed as PII' do
          Candidate.create(id: 123, email_address: 'adrienne@example.com')

          expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
            .with([a_hash_including({
              'data' => match([ # #match will cause a strict match within hash_including
                                { 'key' => 'id', 'value' => [123] }
                              ])
            })])
        end
      end
    end

    context 'when no fields are specified in the analytics file' do
      let(:interesting_fields) { [] }

      it 'does not send create_entity events at all' do
        Candidate.create

        expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
          .with([a_hash_including({ 'event_type' => 'create_entity' })])
      end
    end

    context 'when there is an ignored_column on the entity' do
      let(:interesting_fields) { %w[email_address first_name user_id degree] }

      it 'is included in the payload as a null value' do
        Candidate.create(id: 123, first_name: 'Adrienne', email_address: 'adrienne@example.com', user_id: '45', degree: true)
        Teacher.create(id: 124, first_name: 'Brianne', email_address: 'brianne@example.com', degree: true)
        Assistant.create(id: 125, first_name: 'Taryn', email_address: 'taryn@example.com')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
                'data' => [
                  { 'key' => 'email_address', 'value' => ['adrienne@example.com'] },
                  { 'key' => 'first_name', 'value' => ['Adrienne'] },
                  { 'key' => 'user_id', 'value' => ['45'] },
                  { 'key' => 'degree', 'value' => ['true'] }
                ]
              })])

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
                'data' => [
                  { 'key' => 'email_address', 'value' => ['brianne@example.com'] },
                  { 'key' => 'first_name', 'value' => ['Brianne'] },
                  { 'key' => 'user_id', 'value' => [] },
                  { 'key' => 'degree', 'value' => ['true'] }
                ]
              })])

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
              'data' => [
                { 'key' => 'email_address', 'value' => ['taryn@example.com'] },
                { 'key' => 'first_name', 'value' => ['Taryn'] },
                { 'key' => 'user_id', 'value' => [] },
                { 'key' => 'degree', 'value' => [] }
              ]
            })])
      end
    end
  end

  describe 'update_entity events' do
    context 'when fields are specified in the analytics file' do
      let(:interesting_fields) { %w[email_address first_name] }

      it 'sends update events for fields we care about' do
        entity = Candidate.create(email_address: 'foo@bar.com', first_name: 'Jason')
        entity.update(email_address: 'bar@baz.com')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'entity_table_name' => Candidate.table_name,
            'event_type' => 'update_entity',
            'data' => [
              { 'key' => 'email_address', 'value' => ['bar@baz.com'] },
              { 'key' => 'first_name', 'value' => ['Jason'] }
            ]
          })])
      end

      it 'does not send update events for fields we don’t care about' do
        entity = Candidate.create
        entity.update(last_name: 'GB')

        expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
        .with([a_hash_including({
          'event_type' => 'update_entity'
        })])
      end

      it 'sends events that are valid according to the schema' do
        entity = Candidate.create
        entity.update(email_address: 'bar@baz.com')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later).twice do |payload|
          schema = DfE::Analytics::EventSchema.new.as_json
          schema_validator = JSONSchemaValidator.new(schema, payload.first)

          expect(schema_validator).to be_valid, schema_validator.failure_message
        end
      end
    end

    context 'when no fields are specified in the analytics file' do
      let(:interesting_fields) { [] }

      it 'does not send update events at all' do
        entity = Candidate.create
        entity.update(first_name: 'Persephone')

        expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
        .with([a_hash_including({
          'event_type' => 'update_entity'
        })])
      end
    end
  end

  describe 'delete_entity events' do
    let(:interesting_fields) { ['email_address'] }

    it 'sends events when objects are deleted' do
      entity = Candidate.create(email_address: 'boo@example.com')
      entity.destroy

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'entity_table_name' => Candidate.table_name,
          'event_type' => 'delete_entity',
          'data' => [
            { 'key' => 'email_address', 'value' => ['boo@example.com'] }
          ]
        })])
    end
  end
end
