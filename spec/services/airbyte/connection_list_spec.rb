# frozen_string_literal: true

require_relative '../../../lib/services/airbyte/connection_list'

RSpec.describe Services::Airbyte::ConnectionList do
  let(:access_token) { 'valid-token' }
  let(:client_id) { 'dummy-id' }
  let(:client_secret) { 'dummy-secret' }
  let(:server_url) { 'https://airbyte.example.com' }
  let(:workspace_id) { 'workspace-123' }
  let(:url) { "#{server_url}/api/v1/connections/list" }

  let(:config_double) do
    instance_double(
      'DfE::Analytics,config',
      airbyte_client_id: client_id,
      airbyte_client_secret: client_secret,
      airbyte_server_url: server_url,
      airbyte_workspace_id: workspace_id
    )
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.call' do
    context 'when API returns a connection successfully' do
      let(:mock_response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          parsed_response: {
            'connections' => [
              { 'connectionId' => 'conn-abc', 'sourceId' => 'src-xyz' }
            ]
          }
        )
      end

      it 'returns connection_id and source_id as an array' do
        expect(HTTParty).to receive(:post).with(
          url,
          headers: {
            'Authorization' => "Bearer #{access_token}",
            'Content-Type' => 'application/json'
          },
          body: { workspaceId: workspace_id }.to_json
        ).and_return(mock_response)

        result = described_class.call(access_token:)
        expect(result).to eq(%w[conn-abc src-xyz])
      end
    end

    context 'when API returns no connections' do
      let(:mock_response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          parsed_response: { 'connections' => [] }
        )
      end

      it 'raises an error' do
        allow(HTTParty).to receive(:post).and_return(mock_response)

        expect do
          described_class.call(access_token:)
        end.to raise_error(Services::Airbyte::ConnectionList::Error, /No connections returned/)
      end
    end

    context 'when API call fails' do
      let(:mock_response) do
        instance_double(
          HTTParty::Response,
          success?: false,
          code: 500,
          body: 'Internal Server Error'
        )
      end

      it 'logs and raises an error' do
        allow(HTTParty).to receive(:post).and_return(mock_response)
        expect(Rails.logger).to receive(:error).with(/status: 500/)

        expect do
          described_class.call(access_token:)
        end.to raise_error(Services::Airbyte::ConnectionList::Error, /status: 500/)
      end
    end
  end
end
