# frozen_string_literal: true

require_relative '../../../lib/services/airbyte/connection_update'

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

  let(:config_double) do
    instance_double(
      'DfE::Analytics.config',
      airbyte_server_url: 'https://fake.airbyte.api'
    )
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.call' do
    let(:http_response) do
      instance_double(
        HTTParty::Response,
        success?: true,
        parsed_response: { 'status' => 'ok' }
      )
    end

    before do
      allow(HTTParty).to receive(:post).and_return(http_response)
    end

    it 'calls the Airbyte API and returns parsed response' do
      result = described_class.call(access_token:, connection_id:, allowed_list:, discovered_schema:)

      expect(result).to eq({ 'status' => 'ok' })

      expect(HTTParty).to have_received(:post).with(
        'https://fake.airbyte.api/api/v1/connections/update',
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        },
        body: kind_of(String)
      )
    end

    context 'when stream is missing from discovered schema' do
      let(:discovered_schema) { { 'catalog' => { 'streams' => [] } } }

      it 'raises a ConnectionUpdate::Error' do
        expect(Rails.logger).to receive(:error).with(/Stream definition not found/)

        expect do
          described_class.call(access_token:, connection_id:, allowed_list:, discovered_schema:)
        end.to raise_error(Services::Airbyte::ConnectionUpdate::Error)
      end
    end

    context 'when Airbyte API call fails' do
      let(:http_response) do
        instance_double(
          HTTParty::Response,
          success?: false,
          code: 500,
          body: 'Internal Server Error'
        )
      end

      it 'raises a ConnectionUpdate::Error with status and body' do
        expect(Rails.logger).to receive(:error).with(/Error calling Airbyte discover_schema API/)

        expect do
          described_class.call(access_token:, connection_id:, allowed_list:, discovered_schema:)
        end.to raise_error(Services::Airbyte::ConnectionUpdate::Error)
      end
    end

    it 'sends the correct connection update payload structure' do
      described_class.call(access_token:, connection_id:, allowed_list:, discovered_schema:)

      expect(HTTParty).to have_received(:post) do |url, options|
        expect(url).to eq('https://fake.airbyte.api/api/v1/connections/update')

        payload = JSON.parse(options[:body])

        expect(payload['connectionId']).to eq(connection_id)
        expect(payload['syncCatalog']).to be_a(Hash)
        expect(payload['syncCatalog']['streams'].size).to eq(1)

        stream = payload['syncCatalog']['streams'].first

        expect(stream['stream']['name']).to eq('academic_cycles')
        expect(stream['stream']['namespace']).to eq('public')
        expect(stream['config']['syncMode']).to eq('incremental')
        expect(stream['config']['destinationSyncMode']).to eq('append')
        expect(stream['config']['cursorField']).to eq(['_ab_cdc_lsn'])
        expect(stream['config']['primaryKey']).to eq([['id']])

        expected_selected_fields = %w[
          _ab_cdc_lsn _ab_cdc_deleted_at _ab_cdc_updated_at
          created_at end_date id start_date updated_at
        ].map { |f| { 'fieldPath' => [f] } }

        expect(stream['config']['selectedFields']).to match_array(expected_selected_fields)
      end
    end
  end
end
