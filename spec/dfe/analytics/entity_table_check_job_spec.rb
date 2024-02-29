# frozen_string_literal: true

RSpec.describe DfE::Analytics::EntityTableCheckJob do
  include ActiveJob::TestHelper

  with_model :Candidate do
    table do |t|
      t.string :email_address
      t.string :first_name
      t.string :last_name
      t.datetime :updated_at
    end
  end

  with_model :Application do
    table do |t|
      t.string :type
      t.datetime :created_at
    end
  end

  describe '#perform' do
    context 'when entity table checks are not enabled' do
      before do
        allow(DfE::Analytics).to receive(:entity_table_checks_enabled?).and_return(false)
      end

      it 'does not call EntityTableChecks' do
        expect(DfE::Analytics::Services::EntityTableChecks).not_to receive(:call)

        described_class.new.perform
      end
    end

    context 'when entity table checks are enabled' do
      before do
        allow(DfE::Analytics).to receive(:entity_table_checks_enabled?).and_return(true)
        allow(DfE::Analytics).to receive(:entities_for_analytics).and_return(%w[Candidate Application])
      end

      it 'calls EntityTableChecks for each entity' do
        expect(DfE::Analytics::Services::EntityTableChecks).to receive(:call).twice

        described_class.new.perform
      end
    end
  end
end
