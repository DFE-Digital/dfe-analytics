# frozen_string_literal: true

RSpec.describe DfE::Analytics::AirbyteStreamConfig do
  let(:mock_path) { '/fake/path/airbyte_config.json' }

  before do
    allow(DfE::Analytics.config).to receive(:airbyte_stream_config_path).and_return(mock_path)
  end

  describe '.config' do
    context 'when file contains valid JSON' do
      let(:json_data) do
        {
          configurations: {
            streams: [
              {
                name: 'users',
                syncMode: 'incremental_append',
                cursorField: ['_ab_cdc_lsn'],
                primaryKey: [['id']],
                selectedFields: [
                  { fieldPath: ['_ab_cdc_lsn'] },
                  { fieldPath: ['_ab_cdc_updated_at'] },
                  { fieldPath: ['_ab_cdc_deleted_at'] },
                  { fieldPath: ['email'] },
                  { fieldPath: ['name'] }
                ]
              }
            ]
          }
        }.to_json
      end

      before do
        allow(File).to receive(:read).with(mock_path).and_return(json_data)
      end

      it 'returns the deep symbolized hash' do
        expect(described_class.config).to include(
          configurations: {
            streams: include(
              a_hash_including(
                name: 'users',
                selectedFields: include({ fieldPath: ['email'] })
              )
            )
          }
        )
      end
    end

    context 'when File.read raises a RuntimeError' do
      before do
        allow(File).to receive(:read).with(mock_path).and_raise(RuntimeError)
      end

      it 'returns an empty hash' do
        expect(described_class.config).to eq({})
      end
    end
  end

  describe '.generate_for' do
    subject(:parsed_config) { JSON.parse(described_class.generate_for(entity_attributes)) }

    context 'when attributes include "id"' do
      let(:entity_attributes) { { 'users' => %w[id name email] } }

      it 'uses "id" as the primary key and includes all fields' do
        streams = parsed_config['configurations']['streams']
        users_stream = streams.find { |stream| stream['name'] == 'users' }

        expect(users_stream['name']).to eq('users')
        expect(users_stream['syncMode']).to eq('incremental_append')
        expect(users_stream['cursorField']).to eq(['_ab_cdc_lsn'])
        expect(users_stream['primaryKey']).to eq([['id']])
        expect(users_stream['selectedFields'])
          .to match_array([
                            { 'fieldPath' => ['_ab_cdc_lsn'] },
                            { 'fieldPath' => ['_ab_cdc_updated_at'] },
                            { 'fieldPath' => ['_ab_cdc_deleted_at'] },
                            { 'fieldPath' => ['id'] },
                            { 'fieldPath' => ['name'] },
                            { 'fieldPath' => ['email'] }
                          ])
      end

      it 'adds the airbyte heartbeat stream' do
        streams = parsed_config['configurations']['streams']
        heartbeat_stream = streams.find { |stream| stream['name'] == 'airbyte_heartbeat' }

        expect(heartbeat_stream).to include(
          'name' => 'airbyte_heartbeat',
          'syncMode' => 'full_refresh_overwrite',
          'cursorField' => ['_ab_cdc_lsn'],
          'primaryKey' => [['id']]
        )

        expect(heartbeat_stream['selectedFields'])
          .to match_array([
                            { 'fieldPath' => ['_ab_cdc_lsn'] },
                            { 'fieldPath' => ['_ab_cdc_updated_at'] },
                            { 'fieldPath' => ['_ab_cdc_deleted_at'] },
                            { 'fieldPath' => ['id'] },
                            { 'fieldPath' => ['last_heartbeat'] }
                          ])
      end
    end

    context 'when attributes do not include "id"' do
      let(:entity_attributes) { { 'users' => %w[email name] } }

      it 'uses the first attribute as the primary key' do
        streams = parsed_config['configurations']['streams']
        users_stream = streams.find { |stream| stream['name'] == 'users' }

        expect(users_stream['primaryKey']).to eq([['email']])
      end
    end
  end

  describe '.entity_attributes' do
    context 'when config is empty' do
      before { allow(described_class).to receive(:config).and_return({}) }

      it 'returns an empty hash' do
        expect(described_class.entity_attributes).to eq({})
      end
    end

    context 'when config contains streams including the heartbeat stream' do
      let(:config_hash) do
        {
          configurations: {
            streams: [
              {
                name: 'schools',
                syncMode: 'incremental_append',
                cursorField: ['_ab_cdc_lsn'],
                primaryKey: [['id']],
                selectedFields: [
                  { fieldPath: ['_ab_cdc_lsn'] },
                  { fieldPath: ['_ab_cdc_updated_at'] },
                  { fieldPath: ['_ab_cdc_deleted_at'] },
                  { fieldPath: ['id'] },
                  { fieldPath: ['urn'] },
                  { fieldPath: ['name'] }
                ]
              },
              {
                name: 'teachers',
                syncMode: 'incremental_append',
                cursorField: ['_ab_cdc_lsn'],
                primaryKey: [['id']],
                selectedFields: [
                  { fieldPath: ['_ab_cdc_lsn'] },
                  { fieldPath: ['_ab_cdc_updated_at'] },
                  { fieldPath: ['_ab_cdc_deleted_at'] },
                  { fieldPath: ['id'] },
                  { fieldPath: ['trn'] },
                  { fieldPath: ['dob'] }
                ]
              },
              {
                name: 'airbyte_heartbeat',
                syncMode: 'full_refresh_overwrite',
                cursorField: ['_ab_cdc_lsn'],
                primaryKey: [['id']],
                selectedFields: [
                  { fieldPath: ['_ab_cdc_lsn'] },
                  { fieldPath: ['_ab_cdc_updated_at'] },
                  { fieldPath: ['_ab_cdc_deleted_at'] },
                  { fieldPath: ['id'] },
                  { fieldPath: ['last_heartbeat'] }
                ]
              }
            ]
          }
        }
      end

      before do
        allow(described_class).to receive(:config).and_return(config_hash.deep_symbolize_keys)
      end

      it 'removes the cursor and airbyte fields and returns attributes for all streams' do
        expect(described_class.entity_attributes).to eq(
          schools: %w[id urn name],
          teachers: %w[id trn dob],
          airbyte_heartbeat: %w[id last_heartbeat]
        )
      end
    end
  end
end
