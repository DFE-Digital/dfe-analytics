# frozen_string_literal: true

RSpec.describe DfE::Analytics::TransactionChanges do
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

  describe 'after commit' do
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
        ActiveRecord::Base.transaction do
          entity.update(email_address: 'bar@baz')
        end

        expect(entity.stored_transaction_changes).to eq({ 'email_address' => ['foo@bar', 'bar@baz'] })
      end
    end
  end
end