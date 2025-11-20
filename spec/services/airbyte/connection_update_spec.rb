# frozen_string_literal: true

RSpec.describe Services::Airbyte::ConnectionUpdate do
  let(:access_token) { 'fake-access-token' }
  let(:connection_id) { 'abc-123' }

  let(:allowed_list) do
    {
      academic_cycles: %w[created_at end_date id start_date updated_at]
    }
  end

  let(:discovered_schema) do
    {
      'catalog' => {
        'streams' => [
          {
            'stream' => {
              'name' => 'academic_cycles',
              'jsonSchema' => { 'type' => 'object', 'properties' => {} },
              'namespace' => 'public',
              'supportedSyncModes' => %w[full_refresh incremental]
            },
            'config' => {
              'syncMode' => 'incremental',
              'destinationSyncMode' => 'append',
              'cursorField' => ['_ab_cdc_lsn'],
              'primaryKey' => [['id']]
            }
          }
        ]
      }
    }
  end

  describe '.call' do
    let(:api_result) { { 'status' => 'ok' } }

    before do
      allow(Services::Airbyte::ApiServer).to receive(:post).and_return(api_result)
    end

    it 'delegates to ApiServer and returns parsed response' do
      result = described_class.call(
        access_token:,
        connection_id:,
        allowed_list:,
        discovered_schema:
      )

      expect(result).to eq(api_result)

      expect(Services::Airbyte::ApiServer).to have_received(:post).with(
        path: '/api/v1/connections/update',
        access_token: access_token,
        payload: kind_of(Hash)
      )
    end

    context 'when stream is missing from discovered schema' do
      let(:discovered_schema) { { 'catalog' => { 'streams' => [] } } }

      before { allow(Rails.logger).to receive(:error) }

      it 'logs and raises ConnectionUpdate::Error' do
        expect(Rails.logger).to receive(:error).with(/Stream definition not found/)

        expect do
          described_class.call(
            access_token:,
            connection_id:,
            allowed_list:,
            discovered_schema:
          )
        end.to raise_error(described_class::Error)
      end
    end

    context 'when ApiServer.post raises an error' do
      before do
        allow(Services::Airbyte::ApiServer).to receive(:post)
          .and_raise(Services::Airbyte::ApiServer::Error.new('Boom'))
      end

      it 'does not wrap or swallow ApiServer errors' do
        expect do
          described_class.call(
            access_token:,
            connection_id:,
            allowed_list:,
            discovered_schema:
          )
        end.to raise_error(Services::Airbyte::ApiServer::Error, /Boom/)
      end
    end

    it 'builds and sends the correct connection update payload' do
      described_class.call(
        access_token:,
        connection_id:,
        allowed_list:,
        discovered_schema:
      )

      expect(Services::Airbyte::ApiServer).to have_received(:post) do |args|
        payload = args[:payload]

        expect(payload[:connectionId]).to eq(connection_id)
        expect(payload[:syncCatalog]).to be_a(Hash)
        expect(payload[:syncCatalog][:streams].size).to eq(1)

        stream_payload = payload[:syncCatalog][:streams].first

        expect(stream_payload[:stream][:name]).to eq('academic_cycles')
        expect(stream_payload[:stream][:namespace]).to eq('public')

        config = stream_payload[:config]
        expect(config[:syncMode]).to eq('incremental')
        expect(config[:destinationSyncMode]).to eq('append')
        expect(config[:cursorField]).to eq(['_ab_cdc_lsn'])
        expect(config[:primaryKey]).to eq([['id']])

        # Selected fields include standard ones + allowed list
        expected_fields = %w[
          _ab_cdc_lsn
          _ab_cdc_deleted_at
          _ab_cdc_updated_at
          created_at
          end_date
          id
          start_date
          updated_at
        ].map { |f| { fieldPath: [f] } }

        expect(config[:selectedFields]).to match_array(expected_fields)
      end
    end
  end
end
