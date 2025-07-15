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
              'destinationSyncMode' => 'append_dedup',
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
      result = described_class.call( access_token:, connection_id:, allowed_list:, discovered_schema:)

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
          described_class.call( access_token:, connection_id:, allowed_list:, discovered_schema:)
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
          described_class.call( access_token:, connection_id:, allowed_list:, discovered_schema:)
        end.to raise_error(Services::Airbyte::ConnectionUpdate::Error)
      end
    end
  end
end
