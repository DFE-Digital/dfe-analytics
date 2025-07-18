# frozen_string_literal: true

require_relative '../../../lib/services/airbyte/discover_schema'

RSpec.describe Services::Airbyte::DiscoverSchema do
  let(:access_token) { 'test-token' }
  let(:source_id) { 'source-abc' }
  let(:server_url) { 'https://airbyte.example.com' }
  let(:url) { "#{server_url}/api/v1/sources/discover_schema" }

  let(:config_double) do
    double(
      airbyte_server_url: server_url
    )
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.call' do
    context 'when the request is successful' do
      let(:response_payload) do
        {
          'catalog' => {
            'streams' => [{ 'name' => 'example_stream' }]
          }
        }
      end

      let(:mock_response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          parsed_response: response_payload
        )
      end

      it 'returns the parsed response' do
        expect(HTTParty).to receive(:post).with(
          url,
          headers: {
            'Authorization' => "Bearer #{access_token}",
            'Content-Type' => 'application/json'
          },
          body: { sourceId: source_id }.to_json
        ).and_return(mock_response)

        result = described_class.call(access_token:, source_id:)
        expect(result).to eq(response_payload)
      end
    end

    context 'when the request fails' do
      let(:mock_response) do
        instance_double(
          HTTParty::Response,
          success?: false,
          code: 403,
          body: 'Forbidden'
        )
      end

      it 'logs and raises an error' do
        allow(HTTParty).to receive(:post).and_return(mock_response)
        expect(Rails.logger).to receive(:error).with(/status: 403/)

        expect do
          described_class.call(access_token:, source_id:)
        end.to raise_error(Services::Airbyte::DiscoverSchema::Error, /status: 403/)
      end
    end
  end
end
