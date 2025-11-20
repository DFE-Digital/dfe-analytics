# frozen_string_literal: true

RSpec.describe Services::Airbyte::ApiServer do
  let(:access_token) { 'mock-token' }
  let(:path)         { '/api/v1/jobs/list' }
  let(:payload)      { { connectionId: 'xyz' } }
  let(:server_url)   { 'https://fake.airbyte.internal' }
  let(:full_url)     { "#{server_url}#{path}" }

  # Fake DfE::Analytics.config
  let(:config_double) do
    instance_double('DfE::Analytics.config', airbyte_server_url: server_url)
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.post' do
    context 'when the request is successful' do
      let(:response_body) { { 'status' => 'success' } }
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

      it 'returns parsed response' do
        result = described_class.post(path:, access_token:, payload:)

        expect(result).to eq(response_body)
        expect(HTTParty).to have_received(:post).with(
          full_url,
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{access_token}"
          },
          body: payload.to_json
        )
      end
    end

    context 'when the request returns a non-success HTTP response' do
      let(:http_response) do
        instance_double(
          HTTParty::Response,
          success?: false,
          code: 500,
          body: 'Internal Server Error'
        )
      end

      before do
        allow(HTTParty).to receive(:post).and_return(http_response)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs and raises ApiServer::Error' do
        expect(Rails.logger).to receive(:error).with(
          /Error calling Airbyte API \(#{Regexp.escape(path)}\): status: 500 body: Internal Server Error/
        )

        expect do
          described_class.post(path:, access_token:, payload:)
        end.to raise_error(described_class::Error, /status: 500/)
      end
    end

    context 'when HTTParty.post raises a network error' do
      before do
        allow(HTTParty).to receive(:post).and_raise(SocketError.new('network down'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs and wraps the error' do
        expect(Rails.logger).to receive(:error).with(
          /HTTP post failed to url: #{Regexp.escape(full_url)}, failed with error: network down/
        )

        expect do
          described_class.post(path:, access_token:, payload:)
        end.to raise_error(described_class::Error, /network down/)
      end
    end
  end
end
