# frozen_string_literal: true

RSpec.describe DfE::Analytics::Services::GenericChecksumCalculator do
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
    allow(DfE::Analytics).to receive(:allowlist).and_return({
    Candidate.table_name.to_sym => %w[updated_at]
    })
  end

  let(:order_column) { 'UPDATED_AT' }
  let(:calculator) { described_class.new(entity, order_column, checksum_calculated_at) }
  let(:candidate_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('candidate') } }
  let(:time_zone) { 'London' }
  let(:checksum_calculated_at) { ActiveRecord::Base.connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp').first['current_timestamp'].in_time_zone(time_zone).iso8601(6) }

  before { Timecop.freeze(checksum_calculated_at) }
  after { Timecop.return }

  it 'calculates checksum and row_count accurately' do
    [10, 11, 12].map { |id| Candidate.create(id: id) }
    candidate_table_ids = Candidate.where('updated_at < ?', checksum_calculated_at).order(updated_at: :asc).pluck(:id)
    entity_table_checksum = Digest::MD5.hexdigest(candidate_table_ids.join)

    row_count, checksum = described_class.call(candidate_entity, order_column, checksum_calculated_at)
    expect(row_count).to eq(candidate_table_ids.count)
    expect(checksum).to eq(entity_table_checksum)
  end

  it 'calculates checksum and correct row_count when updated_at has null values' do
    Candidate.create(id: 1, email_address: 'candidate1@example.com', updated_at: nil)
    Candidate.create(id: 2, email_address: 'candidate2@example.com', updated_at: nil)
    Candidate.create(id: 3, email_address: 'candidate3@example.com', updated_at: Time.current - 1.day)
    Candidate.create(id: 4, email_address: 'candidate4@example.com', updated_at: Time.current - 2.days)

    order_column = 'ID' # defaults to ID when order_columns contain null values
    expected_ids = [1, 2, 3, 4]
    expected_checksum = Digest::MD5.hexdigest(expected_ids.join)

    row_count, checksum = described_class.call(candidate_entity, order_column, checksum_calculated_at)

    expect(row_count).to eq(4)
    expect(checksum).to eq(expected_checksum)
  end
end
