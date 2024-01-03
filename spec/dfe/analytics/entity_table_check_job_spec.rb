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

  before do
    DfE::Analytics.config.entity_table_checks_enabled = true
    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
    allow(DfE::Analytics).to receive(:allowlist).and_return({
    Candidate.table_name.to_sym => %w[id updated_at]
    })
    allow(DfE::Analytics).to receive(:allowlist_pii).and_return({
    Candidate.table_name.to_sym => %w[]
    })
    allow(Rails.logger).to receive(:info)
    allow(Time).to receive(:now).and_return(time_now)
  end

  describe '#perform' do
    let(:wait_time) { Date.tomorrow.midnight }
    let(:time_now) { Time.new(2023, 9, 19, 12, 0, 0) }
    let(:time_zone) { 'London' }
    let(:checksum_calculated_at) { ActiveRecord::Base.connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp').first['current_timestamp'].in_time_zone('London').iso8601(6) }
    let(:order_column) { 'UPDATED_AT' }

    before { Timecop.freeze(checksum_calculated_at) }
    after { Timecop.return }

    it 'does not run if entity table check is disabled' do
      DfE::Analytics.config.entity_table_checks_enabled = false

      described_class.new.perform

      expect(DfE::Analytics::SendEvents).not_to have_received(:perform_later)
    end

    it 'sends the entity_table_check event to BigQuery' do
      [123, 124, 125].map { |id| Candidate.create(id: id) }
      table_ids = Candidate.where('updated_at < ?', checksum_calculated_at).order(updated_at: :asc).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)
      described_class.new.perform

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'data' =>
          [
            { 'key' => 'row_count', 'value' => [table_ids.size] },
            { 'key' => 'checksum', 'value' => [checksum] },
            { 'key' => 'checksum_calculated_at', 'value' => [checksum_calculated_at] },
            { 'key' => 'order_column', 'value' => [order_column] }
          ]
        })])
    end

    it 'does not send the event if updated_at is greater than checksum_calculated_at' do
      parsed_time = DateTime.parse(checksum_calculated_at)
      Candidate.create(id: '123', updated_at: parsed_time - 2.hours)
      Candidate.create(id: '124', updated_at: parsed_time - 5.hours)
      Candidate.create(id: '125', updated_at: parsed_time + 5.hours)

      table_ids = Candidate.where('updated_at < ?', checksum_calculated_at).order(updated_at: :asc).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)
      described_class.new.perform

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'data' => [
            { 'key' => 'row_count', 'value' => [table_ids.size] },
            { 'key' => 'checksum', 'value' => [checksum] },
            { 'key' => 'checksum_calculated_at', 'value' => [checksum_calculated_at] },
            { 'key' => 'order_column', 'value' => [order_column] }
          ]
      })])
    end

    it 'returns zero rows and checksum if table is empty' do
      table_ids = Candidate.where('updated_at < ?', checksum_calculated_at).order(updated_at: :asc).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)
      described_class.new.perform

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'data' => [
            { 'key' => 'row_count', 'value' => [0] },
            { 'key' => 'checksum', 'value' => [checksum] },
            { 'key' => 'checksum_calculated_at', 'value' => [checksum_calculated_at] },
            { 'key' => 'order_column', 'value' => [order_column] }
          ]
      })])
    end

    it 'logs the entity name and row count' do
      Candidate.create(id: 123)
      expected_message = "DfE::Analytics Processing entity: #{Candidate.table_name}: Row count: #{Candidate.count}"

      described_class.new.perform

      expect(Rails.logger).to have_received(:info).with(expected_message)
    end
  end
end
