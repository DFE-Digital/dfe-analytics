# frozen_string_literal: true

require_relative '../../../lib/services/airbyte/api_server'

RSpec.describe Services::Airbyte::ApiServer do
  let(:access_token) { 'mock-access-token' }
  let(:path) { '/api/v1/connections/sync' }
  let(:payload) { { connectionId: 'abc-123' } }
  let(:airbyte_url) { 'https://mock.airbyte.internal' }

  let(:config_double) do
    instance_double('DfE::Analytics.config', airbyte_server_url: airbyte_url)
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.post' do
    let(:url) { "#{airbyte_url}#{path}" }

    context 'when the request succeeds' do
      let(:response_body) { { 'status' => 'started' } }
      let(:http_response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          parsed_response: response_body
        )
      end

      before do
        allow(HTTParty).to receive(:post).and_return(http_response)
      end

      it 'calls the Airbyte API and returns parsed response' do
        result = described_class.post(path:, access_token:, payload:)

        expect(result).to eq(response_body)

        expect(HTTParty).to have_received(:post).with(
          url,
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{access_token}"
          },
          body: payload.to_json
        )
      end
    end

    context 'when the request fails' do
      let(:http_response) do
        instance_double(
          HTTParty::Response,
          success?: false,
          code: 403,
          body: 'Forbidden'
        )
      end

      before do
        allow(HTTParty).to receive(:post).and_return(http_response)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and raises ApiServer::Error' do
        expect(Rails.logger).to receive(:error).with(/Error calling Airbyte API \(#{Regexp.escape(path)}\): status: 403 body: Forbidden/)

        expect do
          described_class.post(path:, access_token:, payload:)
        end.to raise_error(described_class::Error, /status: 403/)
      end
    end
  end
end
