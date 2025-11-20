# frozen_string_literal: true

RSpec.describe Services::Airbyte::ApiServer do
  let(:access_token) { 'test-token' }
  let(:path) { '/api/v1/connections/sync' }
  let(:payload) { { connectionId: 'abc-123' } }
  let(:airbyte_url) { 'https://mock.airbyte.api' }
  let(:url) { "#{airbyte_url}#{path}" }

  let(:config_double) do
    instance_double('DfE::Analytics.config', airbyte_server_url: airbyte_url)
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.post' do
    context 'when the request is successful' do
      let(:response_body) { { 'status' => 'ok' } }
      let(:http_response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          parsed_response: response_body
        )
      end

      it 'returns the parsed response' do
        allow(HTTParty).to receive(:post).and_return(http_response)

        result = described_class.post(path: path, access_token: access_token, payload: payload)
        expect(result).to eq(response_body)
      end
    end

    context 'when the response is an HTTP error' do
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
        allow(Rails.logger).to receive(:info)
      end

      it 'logs and raises a HttpError with code and message' do
        expect(Rails.logger).to receive(:info).with(/Error calling Airbyte API/)

        error = nil
        expect do
          described_class.post(path: path, access_token: access_token, payload: payload)
        rescue described_class::HttpError => e
          error = e
          raise
        end.to raise_error(described_class::HttpError)

        expect(error.code).to eq(403)
        expect(error.message).to eq('Forbidden')
      end
    end

    context 'when a low-level network error occurs' do
      before do
        allow(HTTParty).to receive(:post).and_raise(StandardError.new('Socket hang up'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs and raises a generic ApiServer::Error' do
        expect(Rails.logger).to receive(:error).with(/HTTP post failed to url/)

        expect do
          described_class.post(path: path, access_token: access_token, payload: payload)
        end.to raise_error(described_class::Error, /Socket hang up/)
      end
    end
  end
end
