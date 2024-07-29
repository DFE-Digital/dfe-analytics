# frozen_string_literal: true

RSpec.describe DfE::Analytics::Entities do
  let(:allowlist_fields) { [] }
  let(:pii_fields) { [] }
  let(:hidden_pii_fields) { [] }

  with_model :Candidate do
    table do |t|
      t.string :email_address
      t.string :last_name
      t.string :first_name
      t.string :dob
    end
  end

  before do
    stub_const('Teacher', Class.new(Candidate))
    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
    allow(DfE::Analytics).to receive(:enabled?).and_return(true)

    allow(DfE::Analytics).to receive(:allowlist).and_return({
      Candidate.table_name.to_sym => allowlist_fields
    })

    allow(DfE::Analytics).to receive(:allowlist_pii).and_return({
      Candidate.table_name.to_sym => pii_fields
    })

    allow(DfE::Analytics).to receive(:hidden_pii).and_return({
      Candidate.table_name.to_sym => hidden_pii_fields
    })

    # autogenerate a compliant blocklist
    allow(DfE::Analytics).to receive(:blocklist).and_return(DfE::Analytics::Fields.generate_blocklist)

    DfE::Analytics.initialize!
  end

  describe 'create_entity events' do
    context 'when fields are specified in the analytics file' do
      let(:allowlist_fields) { ['id'] }

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
        let(:allowlist_fields) { ['email_address'] }
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
        let(:allowlist_fields) { ['id'] }
        let(:pii_fields) { ['email_address'] }

        it 'does not include the fields only listed as PII' do
          Candidate.create(id: 123, email_address: 'adrienne@example.com')

          expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
            .with([a_hash_including({ # #match will cause a strict match within hash_including
              'data' => match([
                                { 'key' => 'id', 'value' => [123] }
                              ])
            })])
        end
      end
    end

    context 'when no fields are specified in the analytics file' do
      let(:allowlist_fields) { [] }

      it 'does not send create_entity events at all' do
        Candidate.create

        expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
          .with([a_hash_including({ 'event_type' => 'create_entity' })])
      end
    end

    context 'when fields are specified in the analytics and hidden_pii file' do
      let(:allowlist_fields) { %w[email_address dob] }
      let(:hidden_pii_fields) { %w[dob] }

      it 'sends event with separated allowed and hidden data' do
        Candidate.create(email_address: 'foo@bar.com', dob: '20062000')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'event_type' => 'create_entity',
            'data' => array_including(a_hash_including('key' => 'email_address', 'value' => ['foo@bar.com'])),
            'hidden_data' => array_including(a_hash_including('key' => 'dob', 'value' => ['20062000']))
          })])
      end
    end
  end

  describe 'update_entity events' do
    context 'when fields are specified in the analytics file' do
      let(:allowlist_fields) { %w[email_address first_name] }

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
      let(:allowlist_fields) { [] }

      it 'does not send update events at all' do
        entity = Candidate.create
        entity.update(first_name: 'Persephone')

        expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
          .with([a_hash_including({
            'event_type' => 'update_entity'
          })])
      end
    end

    context 'when fields are specified in the analytics and hidden_pii file' do
      let(:candidate) { Candidate.create(email_address: 'name@example.com', dob: '20062000') }
      let(:allowlist_fields) { %w[email_address dob] }
      let(:hidden_pii_fields) { %w[dob] }

      it 'sends events with updated allowed field but without original hidden data' do
        candidate.update(email_address: 'updated@example.com')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'event_type' => 'update_entity',
            'data' => array_including(a_hash_including('key' => 'email_address', 'value' => ['updated@example.com']))
          })])
      end

      it 'sends events with updated allowed field and with updated hidden data' do
        candidate.update(email_address: 'updated@example.com', dob: '21062000')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'event_type' => 'update_entity',
            'data' => array_including(a_hash_including('key' => 'email_address', 'value' => ['updated@example.com'])),
            'hidden_data' => array_including(a_hash_including('key' => 'dob', 'value' => ['21062000']))
          })])
      end
    end
  end

  describe 'delete_entity events' do
    let(:allowlist_fields) { ['email_address'] }

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

    context 'when fields are specified in the analytics and hidden_pii file' do
      let(:allowlist_fields) { %w[email_address dob] }
      let(:hidden_pii_fields) { %w[dob] }

      it 'sends event indicating deletion with allowed and hidden data' do
        entity = Candidate.create(email_address: 'to@be.deleted', dob: '21062000')
        entity.destroy

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'event_type' => 'delete_entity',
            'data' => array_including(a_hash_including('key' => 'email_address')),
            'hidden_data' => array_including(a_hash_including('key' => 'dob', 'value' => ['21062000']))
          })])
      end
    end
  end

  describe 'rollback behavior' do
    it 'does not send create event if the transaction is rolled back' do
      ActiveRecord::Base.transaction do
        Candidate.create(id: 123)
        raise ActiveRecord::Rollback
      end

      expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
    end

    it 'does not send update event if the transaction is rolled back' do
      entity = Candidate.create(email_address: 'foo@bar.com', first_name: 'Jason')
      ActiveRecord::Base.transaction do
        entity.update(email_address: 'bar@baz.com')
        raise ActiveRecord::Rollback
      end

      expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
    end

    it 'does not send delete event if the transaction is rolled back' do
      entity = Candidate.create(email_address: 'boo@example.com')
      ActiveRecord::Base.transaction do
        entity.destroy
        raise ActiveRecord::Rollback
      end

      expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
    end
  end
end
