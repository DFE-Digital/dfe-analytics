# frozen_string_literal: true

RSpec.describe DfE::Analytics::TransactionChanges do
  let(:allowlist_fields) { [] }
  let(:hidden_pii_fields) { [] }

  with_model :Candidate do
    table do |t|
      t.string :email_address
      t.string :last_name
      t.string :first_name
      t.string :dob
    end

    model do
      include DfE::Analytics::TransactionChanges
      attr_accessor :stored_transaction_changes

      after_commit :store_transaction_changes_for_tests

      def store_transaction_changes_for_tests
        @stored_transaction_changes = transaction_changed_attributes.reduce({}) do |changes, (attr_name, value)|
          changes[attr_name] = [value, send(attr_name)]
          changes
        end
      end
    end
  end

  before do
    allow(DfE::Analytics).to receive(:allowlist).and_return({
      Candidate.table_name.to_sym => allowlist_fields
    })

    allow(DfE::Analytics).to receive(:hidden_pii).and_return({
      Candidate.table_name.to_sym => hidden_pii_fields
    })

    # autogenerate a compliant blocklist
    allow(DfE::Analytics).to receive(:blocklist).and_return(DfE::Analytics::Fields.generate_blocklist)

    DfE::Analytics.initialize!
  end

  describe 'after commit' do
    let(:allowlist_fields) { %w[id email_address] }
    context 'without transaction' do
      it 'create tracks changes to attributes' do
        entity = Candidate.create(email_address: 'foo@bar')

        expect(entity.stored_transaction_changes).to eq({ 'email_address' => [nil, 'foo@bar'], 'id' => [nil, 1] })
      end

      it 'update tracks changes to attributes' do
        entity = Candidate.create(email_address: 'foo@bar')
        entity.update(email_address: 'bar@baz')

        expect(entity.stored_transaction_changes).to eq({ 'email_address' => ['foo@bar', 'bar@baz'] })
      end
    end

    context 'with transaction' do
      it 'create tracks changes to attributes' do
        ActiveRecord::Base.transaction do
          @entity = Candidate.create(email_address: 'foo@bar')
        end

        expect(@entity.stored_transaction_changes).to eq({ 'email_address' => [nil, 'foo@bar'], 'id' => [nil, 1] })
      end

      it 'update tracks changes to attributes' do
        entity = Candidate.create(email_address: 'foo@bar')
        entity1 = Candidate.create(email_address: 'doo@bar')

        ActiveRecord::Base.transaction do
          entity.update(email_address: 'bar@baz')
          entity1.update(email_address: 'jar@baz')
        end

        expect(entity.stored_transaction_changes).to eq({ 'email_address' => ['foo@bar', 'bar@baz'] })
        expect(entity1.stored_transaction_changes).to eq({ 'email_address' => ['doo@bar', 'jar@baz'] })
      end
    end

    context 'with transaction rollback' do
      it 'create tracks changes to attributes' do
        ActiveRecord::Base.transaction do
          @entity = Candidate.create(email_address: 'foo@bar')
          raise ActiveRecord::Rollback
        end

        expect(@entity.stored_transaction_changes).to be_nil
      end

      it 'update tracks changes to attributes' do
        entity = Candidate.create(email_address: 'foo@bar')
        ActiveRecord::Base.transaction do
          entity.update(email_address: 'bar@baz')
          raise ActiveRecord::Rollback
        end

        expect(entity.stored_transaction_changes).to eq({ 'email_address' => [nil, 'foo@bar'], 'id' => [nil, 1] })
      end
    end
  end
end
