# frozen_string_literal: true

RSpec.describe DfE::Analytics::Entities do
  let(:interesting_fields) { [] }
  let(:pii_fields) { [] }

  let(:model) do
    Class.new(Candidate) do
      include DfE::Analytics::Entities

      # yes, ugh, but another part of the code is going to enumerate
      # descendants of activerecord and map them tables, and if the test for
      # that code runs after this then a class without a .name means we map
      # from nil.
      #
      # Assigning the class to a constant is another way to name it, but that
      # creates _other_ problems, such as the fact that aforementioned test
      # will expect the class to be called "Candidate" and there will exist a
      # class called "model" referencing the same table.
      def self.name
        'Candidate'
      end
    end
  end

  before do
    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
    allow(DfE::Analytics).to receive(:enabled?).and_return(true)

    allow(DfE::Analytics).to receive(:allowlist).and_return({
      candidates: interesting_fields
    })

    allow(DfE::Analytics).to receive(:allowlist_pii).and_return({
      candidates: pii_fields
    })
  end

  describe 'create_entity events' do
    context 'when fields are specified in the analytics file' do
      let(:interesting_fields) { [:id] }

      it 'includes attributes specified in the settings file' do
        model.create(id: 123)

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'entity_table_name' => 'candidates',
            'event_type' => 'create_entity',
            'data' => [
              { 'key' => 'id', 'value' => [123] }
            ]
          })])
      end

      it 'does not include attributes not specified in the settings file' do
        model.create(id: 123, email_address: 'a@b.com')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'entity_table_name' => 'candidates',
            'event_type' => 'create_entity',
            'data' => [
              { 'key' => 'id', 'value' => [123] }
              # ie the same payload as above
            ]
          })])
      end

      it 'sends events that are valid according to the schema' do
        model.create

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later) do |payload|
          schema = File.read('config/event-schema.json')
          schema_validator = JSONSchemaValidator.new(schema, payload.first)

          expect(schema_validator).to be_valid, schema_validator.failure_message
        end
      end

      it 'sends events with the request UUID, if available' do
        RequestLocals.store[:dfe_analytics_request_id] = 'example-request-id'

        model.create

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'request_uuid' => 'example-request-id'
          })])
      end

      context 'and the specified fields are listed as PII' do
        let(:interesting_fields) { [:email_address] }
        let(:pii_fields) { [:email_address] }

        it 'hashes those fields' do
          model.create(email_address: 'adrienne@example.com')

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
        let(:interesting_fields) { [:id] }
        let(:pii_fields) { [:email_address] }

        it 'does not include the fields only listed as PII' do
          model.create(id: 123, email_address: 'adrienne@example.com')

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
        model.create

        expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
          .with([a_hash_including({ 'event_type' => 'create_entity' })])
      end
    end
  end

  describe 'update_entity events' do
    context 'when fields are specified in the analytics file' do
      let(:interesting_fields) { %i[email_address first_name] }

      it 'sends update events for fields we care about' do
        entity = model.create(email_address: 'foo@bar.com', first_name: 'Jason')
        entity.update(email_address: 'bar@baz.com')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([a_hash_including({
            'entity_table_name' => 'candidates',
            'event_type' => 'update_entity',
            'data' => [
              { 'key' => 'email_address', 'value' => ['bar@baz.com'] },
              { 'key' => 'first_name', 'value' => ['Jason'] }
            ]
          })])
      end

      it 'does not send update events for fields we don’t care about' do
        entity = model.create
        entity.update(last_name: 'GB')

        expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
          .with a_hash_including({
            'event_type' => 'update_entity'
          })
      end

      it 'sends events that are valid according to the schema' do
        entity = model.create
        entity.update(email_address: 'bar@baz.com')

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later).twice do |payload|
          schema = File.read('config/event-schema.json')
          schema_validator = JSONSchemaValidator.new(schema, payload.first)

          expect(schema_validator).to be_valid, schema_validator.failure_message
        end
      end
    end

    context 'when no fields are specified in the analytics file' do
      let(:interesting_fields) { [] }

      it 'does not send update events at all' do
        entity = model.create
        entity.update(first_name: 'Persephone')

        expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
          .with a_hash_including({
            'event_type' => 'update_entity'
          })
      end
    end
  end

  describe 'delete_entity events' do
    let(:interesting_fields) { [:email_address] }

    it 'sends events when objects are deleted' do
      entity = model.create(email_address: 'boo@example.com')
      entity.destroy

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'entity_table_name' => 'candidates',
          'event_type' => 'delete_entity',
          'data' => [
            { 'key' => 'email_address', 'value' => ['boo@example.com'] }
          ]
        })])
    end
  end
end
