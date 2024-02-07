# frozen_string_literal: true

RSpec.describe DfE::Analytics::Services::EntityTableChecks do
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
    Candidate.table_name.to_sym => %w[updated_at],
    Application.table_name.to_sym => %w[type created_at],
    Course.table_name.to_sym => %w[name duration],
    Department.table_name.to_sym => %w[name],
    Institution.table_name.to_sym => %w[id name address]
    })
    allow(Rails.logger).to receive(:info)
    # allow(Time).to receive(:now).and_return(time_now)
  end

  describe '#call' do
    # let(:time_now) { Time.new(2023, 9, 19, 12, 0, 0) }
    let(:time_zone) { 'London' }
    let(:checksum_calculated_at) { ActiveRecord::Base.connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp').first['current_timestamp'].in_time_zone(time_zone).iso8601(6) }
    let(:order_column) { 'UPDATED_AT' }
    let(:course_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('course') } }
    let(:institution_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('institution') } }
    let(:application_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('application') } }
    let(:candidate_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('candidate') } }
    let(:department_entity) { DfE::Analytics.entities_for_analytics.find { |entity| entity.to_s.include?('department') } }
    let(:entity_type) { 'entity_table_check' }

    before { Timecop.freeze(checksum_calculated_at) }
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
    end

    it 'does not send the event if updated_at is greater than checksum_calculated_at' do
      parsed_time = DateTime.parse(checksum_calculated_at)
      Candidate.create(id: '123', updated_at: parsed_time - 2.hours)
      Candidate.create(id: '124', updated_at: parsed_time - 5.hours)
      Candidate.create(id: '125', updated_at: parsed_time + 5.hours)

      table_ids = Candidate.where('updated_at < ?', checksum_calculated_at).order(updated_at: :asc).pluck(:id)
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
        expect(events.first['event_tags']).to eq(entity_tag)
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
  end
end
