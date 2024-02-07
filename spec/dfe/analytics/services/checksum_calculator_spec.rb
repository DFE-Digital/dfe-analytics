# frozen_string_literal: true

RSpec.describe DfE::Analytics::Services::ChecksumCalculator do
  with_model :Candidate do
    table do |t|
      t.string :email_address
      t.string :first_name
      t.string :last_name
      t.datetime :updated_at
    end
  end

  before do
    DfE::Analytics.config.entity_table_checks_enabled = true
    # allow(DfE::Analytics::SendEvents).to receive(:perform_later)
    allow(DfE::Analytics).to receive(:allowlist).and_return({
    Candidate.table_name.to_sym => %w[updated_at]
    })
  end

  describe '#call' do
    let(:time_zone) { 'London' }
    let(:candidate_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('candidate') } }
    let(:entity_type) { 'entity_table_check' }
    let(:order_column) { 'UPDATED_AT' }
    let(:checksum_calculated_at) { ActiveRecord::Base.connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp').first['current_timestamp'].in_time_zone(time_zone).iso8601(6) }

    before { Timecop.freeze(checksum_calculated_at) }
    after { Timecop.return }

    context 'when the adapter is Postgres' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return('postgresql')
      end

      it 'delegates to PostgresChecksumCalculator' do
        expect(DfE::Analytics::Services::PostgresChecksumCalculator).to receive(:call).with(candidate_entity, order_column, checksum_calculated_at)

        described_class.call(candidate_entity, order_column, checksum_calculated_at)
      end
    end

    context 'when the adapter is SQLite' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return('sqlite')
      end

      it 'delegates to PostgresChecksumCalculator' do
        expect(DfE::Analytics::Services::GenericChecksumCalculator).to receive(:call).with(candidate_entity, order_column, checksum_calculated_at)

        described_class.call(candidate_entity, order_column, checksum_calculated_at)
      end
    end
  end
end
