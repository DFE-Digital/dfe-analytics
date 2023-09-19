# frozen_string_literal: true

RSpec.describe DfE::Analytics::EntityTableCheckJob do
  include ActiveJob::TestHelper

  with_model :Candidate do
    table do |t|
      t.string :email_address
      t.string :first_name
      t.string :last_name
    end
  end

  before do
    allow(DfE::Analytics::EntityTableCheckJob).to receive(:perform_later)
    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
    allow(DfE::Analytics).to receive(:allowlist).and_return({
    Candidate.table_name.to_sym => %w[id]
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
    let(:formatted_time) { time_now.in_time_zone(time_zone).iso8601(6) }

    it 'sends the entity_table_check event to BigQuery' do
      [123, 124, 125].map { |id| Candidate.create(id: id) }
      table_ids = Candidate.order(id: :asc).pluck(:id).join
      checksum = Digest::SHA256.hexdigest(table_ids)
      described_class.new.perform

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'entity_table_name' => Candidate.table_name,
          'event_type' => 'entity_table_check',
          'data' => [
            { 'key' => 'number_of_rows', 'value' => [Candidate.count] },
            { 'key' => 'checksum', 'value' => [checksum] },
            { 'key' => 'timestamp', 'value' => [formatted_time] }
          ]
      })])
    end

    it 'reschedules the job to the expected wait time' do
      expected_time = Date.tomorrow.midnight.to_i
      described_class.new.perform

      assert_enqueued_with(job: described_class) do
        described_class.set(wait_until: wait_time).perform_later
      end

      enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
      expect(enqueued_job[:at].to_i).to be_within(2).of(expected_time)
    end

    it 'logs the entity name and row count' do
      Candidate.create(id: 123)
      described_class.new.perform

      expect(Rails.logger).to have_received(:info)
      .with("Processing data for #{Candidate.table_name} with row count #{Candidate.count}")
    end
  end
end
