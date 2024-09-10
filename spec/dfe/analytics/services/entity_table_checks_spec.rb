# frozen_string_literal: true

RSpec.describe DfE::Analytics::Services::EntityTableChecks do
  include ActiveJob::TestHelper

  with_model :Candidate do
    table do |t|
      t.string :email_address
      t.string :first_name
      t.string :last_name
      t.datetime :created_at
      t.datetime :updated_at
    end
  end

  with_model :Application do
    table do |t|
      t.string :type
      t.datetime :created_at
    end
  end

  with_model :Course do
    table id: false do |t|
      t.string :name
      t.string :duration
      t.datetime :updated_at
    end

    model do |m|
      m.primary_key = nil
    end
  end

  with_model :Department do
    table do |t|
      t.string :name
    end
  end

  with_model :Institution do
    table do |t|
      t.string :name
      t.string :address
    end
  end

  before do
    DfE::Analytics.config.entity_table_checks_enabled = true
    allow(DfE::Analytics::SendEvents).to receive(:perform_later)
    allow(DfE::Analytics).to receive(:allowlist).and_return({
    Candidate.table_name.to_sym => %w[updated_at created_at id],
    Application.table_name.to_sym => %w[type created_at],
    Course.table_name.to_sym => %w[name duration],
    Department.table_name.to_sym => %w[name],
    Institution.table_name.to_sym => %w[id name address]
    })
    allow(Rails.logger).to receive(:info)
  end

  describe '#call' do
    let(:time_zone) { 'London' }
    let(:order_column) { 'UPDATED_AT' }
    let(:course_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('course') } }
    let(:institution_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('institution') } }
    let(:application_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('application') } }
    let(:candidate_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('candidate') } }
    let(:department_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('department') } }
    let(:entity_type) { 'entity_table_check' }
    let(:checksum_calculated_at) { @checksum_calculated_at }
    let(:current_timestamp) do
      ActiveRecord::Base.connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp').first['current_timestamp'].in_time_zone(time_zone)
    end
    let(:checksum_calculated_at) { current_timestamp.iso8601(6) }

    before do
      Timecop.freeze(current_timestamp)
    end
    after { Timecop.return }

    it 'returns if the adapter or environment is unsupported' do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect(described_class.call(entity_name: course_entity, entity_type: entity_type, entity_tag: nil)).to be_nil
    end

    it 'skips an entity if there is no id' do
      expected_message = "DfE::Analytics: Entity checksum: ID column missing in #{course_entity} - Skipping checks"
      DfE::Analytics::Services::EntityTableChecks.call(entity_name: course_entity, entity_type: entity_type, entity_tag: nil)
      expect(Rails.logger).to have_received(:info).with(expected_message)
    end

    it 'returns unless the order column is exposed for the entity' do
      expected_message = "DfE::Analytics Processing entity: Order columns missing in analytics.yml for #{department_entity} - Skipping checks"

      expect(described_class.call(entity_name: department_entity, entity_type: entity_type, entity_tag: nil)).to be_nil
      expect(Rails.logger).to have_received(:info).with(expected_message)
    end

    it 'uses updated_at if it exists and has no null values' do
      Candidate.create!(id: 1, email_address: 'first@example.com', updated_at: Time.current)
      Candidate.create!(id: 2, email_address: 'second@example.com', updated_at: Time.current + 1.minute)

      table_ids = Candidate.order(:updated_at).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)

      described_class.call(entity_name: candidate_entity, entity_type: entity_type, entity_tag: nil)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'data' => [
            { 'key' => 'row_count', 'value' => [table_ids.size] },
            { 'key' => 'checksum', 'value' => [checksum] },
            { 'key' => 'checksum_calculated_at', 'value' => [checksum_calculated_at] },
            { 'key' => 'order_column', 'value' => ['UPDATED_AT'] }
          ]
      })])
    end

    it 'falls back to id when both updated_at and created_at are null' do
      frozen_time = Time.zone.now.in_time_zone('London')
      Timecop.freeze(frozen_time)

      candidate1 = Candidate.create!(id: 1, email_address: 'first@example.com')
      candidate2 = Candidate.create!(id: 2, email_address: 'second@example.com')
      candidate3 = Candidate.create!(id: 3, email_address: 'third@example.com')

      candidate1.update_columns(created_at: nil, updated_at: nil)
      candidate2.update_columns(created_at: nil, updated_at: nil)
      candidate3.update_columns(created_at: nil, updated_at: nil)

      table_ids = Candidate.order(:id).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)

      described_class.call(entity_name: candidate_entity, entity_type: entity_type, entity_tag: nil)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'data' => [
            { 'key' => 'row_count', 'value' => [table_ids.size] },
            { 'key' => 'checksum', 'value' => [checksum] },
            { 'key' => 'checksum_calculated_at', 'value' => a_string_including(frozen_time.iso8601(6)) },
            { 'key' => 'order_column', 'value' => ['ID'] }
          ]
      })])

      Timecop.return
    end

    it 'falls back to created_at when updated_at is null but created_at exists' do
      Candidate.create!(id: 1, email_address: 'first@example.com', updated_at: nil, created_at: 2.hours.ago)
      Candidate.create!(id: 2, email_address: 'second@example.com', updated_at: nil, created_at: 1.hour.ago)
      Candidate.create!(id: 3, email_address: 'third@example.com', updated_at: nil, created_at: 3.hours.ago)

      # Ensure updated_at is nil
      Candidate.update_all(updated_at: nil)

      table_ids = Candidate.order(:created_at).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)

      described_class.call(entity_name: candidate_entity, entity_type: entity_type, entity_tag: nil)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
        .with([a_hash_including({
          'data' => [
            { 'key' => 'row_count', 'value' => [table_ids.size] },
            { 'key' => 'checksum', 'value' => [checksum] },
            { 'key' => 'checksum_calculated_at', 'value' => [checksum_calculated_at] },
            { 'key' => 'order_column', 'value' => ['CREATED_AT'] }
          ]
      })])
    end

    it 'orders by created_at if updated_at is missing' do
      order_column = 'CREATED_AT'
      [123, 124, 125].map { |id| Application.create(id: id) }
      application_entities = DfE::Analytics.entities_for_analytics.select { |entity| entity.to_s.include?('application') }
      table_ids = Application.where('created_at < ?', checksum_calculated_at).order(created_at: :asc).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)

      application_entities.each do |application|
        described_class.call(entity_name: application, entity_type: entity_type, entity_tag: nil)
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
    end

    it 'sends an entity table check event' do
      [130, 131, 132].map { |id| Candidate.create(id: id) }
      candidate_entities = DfE::Analytics.entities_for_analytics.select { |entity| entity.to_s.include?('candidate') }
      table_ids = Candidate.where('updated_at < ?', checksum_calculated_at).order(updated_at: :asc).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)

      candidate_entities.each do |candidate|
        described_class.call(entity_name: candidate, entity_type: entity_type, entity_tag: nil)

        expect(DfE::Analytics::SendEvents).to have_received(:perform_later)
          .with([hash_including({
            'data' => [
              { 'key' => 'row_count', 'value' => [table_ids.size] },
              { 'key' => 'checksum', 'value' => [checksum] },
              { 'key' => 'checksum_calculated_at', 'value' => [checksum_calculated_at] },
              { 'key' => 'order_column', 'value' => [order_column] }
            ]
          })])
      end
    end

    it 'does not send the event if updated_at is greater than checksum_calculated_at' do
      Candidate.create(id: '123', updated_at: DateTime.parse(checksum_calculated_at) - 2.hours)
      Candidate.create(id: '124', updated_at: DateTime.parse(checksum_calculated_at) - 5.hours)
      Candidate.create(id: '125', updated_at: DateTime.parse(checksum_calculated_at) + 5.hours)

      table_ids = Candidate.where('updated_at < ?', checksum_calculated_at).order(:updated_at).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)

      described_class.call(entity_name: candidate_entity, entity_type: entity_type, entity_tag: nil)

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
      described_class.call(entity_name: candidate_entity, entity_type: entity_type, entity_tag: nil)

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

    it 'sends different event data based on entity_type' do
      described_class.call(entity_name: candidate_entity, entity_type: 'import_entity_table_check', entity_tag: nil)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later) do |events|
        expect(events.first['event_type']).to eq('import_entity_table_check')
      end
    end

    it 'adds an event_tag to all events for a given import in the format YYYYMMDDHHMMSS' do
      entity_tag = Time.now.strftime('%Y%m%d%H%M%S')
      Candidate.create(id: '324')
      Candidate.create(id: '325')
      described_class.call(entity_name: candidate_entity, entity_type: 'import_entity_table_check', entity_tag: entity_tag)

      expect(DfE::Analytics::SendEvents).to have_received(:perform_later) do |events|
        expect(events.first['event_type']).to eq('import_entity_table_check')
        expect(events.first['event_tags']).to eq([entity_tag])
      end
    end

    it 'orders by id if created_at and updated_at are missing for Institution' do
      order_column = 'ID'

      ['Institute A', 'Institute B', 'Institute C'].each { |name| Institution.create(name: name, address: 'Some address') }

      institution_entities = DfE::Analytics.entities_for_analytics.select { |entity| entity.to_s.include?('institution') }

      table_ids = Institution.order(id: :asc).pluck(:id)
      checksum = Digest::MD5.hexdigest(table_ids.join)

      institution_entities.each do |entity|
        described_class.call(entity_name: entity, entity_type: entity_type, entity_tag: nil)
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
    end

    it 'orders records by updated_at truncated to milliseconds' do
      time_base = Time.zone.now.beginning_of_minute
      Candidate.create(email_address: 'first@example.com', updated_at: time_base + 0.001.seconds)
      Candidate.create(email_address: 'second@example.com', updated_at: time_base + 0.005.seconds)

      described_class.call(entity_name: candidate_entity, entity_type: entity_type, entity_tag: nil)

      ordered_candidates = Candidate.order(:updated_at).pluck(:email_address)

      expect(ordered_candidates).to eq(['first@example.com', 'second@example.com'])
    end
  end
end
