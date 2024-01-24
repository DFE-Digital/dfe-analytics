# frozen_string_literal: true

require_relative '../../../lib/dfe/analytics/shared/checksum_logic'

RSpec.describe DfE::Analytics::EntityProcessor do
  include ActiveJob::TestHelper

  with_model :Candidate do
    table do |t|
      t.string :email_address
      t.string :first_name
      t.string :last_name
      t.datetime :updated_at
    end
  end

  describe '.send_entity_table_check_event' do
    let(:time_now) { Time.new(2023, 9, 19, 12, 0, 0) }
    let(:import_entity_id) { '20230919123000' }
    let(:time_zone) { 'London' }
    let(:order_column) { 'UPDATED_AT' }

    before do
      allow(DfE::Analytics::SendEvents).to receive(:perform_later)
      allow(DfE::Analytics).to receive(:allowlist).and_return({
    Candidate.table_name.to_sym => %w[email_address updated_at]
})
    end

    it 'sends an import_entity_table_check event' do
      entity_name = DfE::Analytics.entities_for_analytics.first
      described_class.send_import_entity_table_check_event(entity_name, import_entity_id, order_column)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later).once do |payload|
        schema = DfE::Analytics::EventSchema.new.as_json
        schema_validator = JSONSchemaValidator.new(schema, payload)

        expect(schema_validator).to be_valid, schema_validator.failure_message

        event_hash = payload.first

        expect(event_hash['event_type']).to eq('import_entity_table_check')
        expect(event_hash['entity_table_name']).to eq(entity_name.to_s)
        expect(event_hash['event_tags']).to include(import_entity_id)
      end
    end
  end
end
