# frozen_string_literal: true

require_relative '../../../lib/services/airbyte/access_token'

RSpec.describe Services::Airbyte::AccessToken do
  let(:client_id) { 'test-client-id' }
  let(:client_secret) { 'test-client-secret' }
  let(:server_url) { 'https://fake.airbyte.api' }
  let(:token_url) { "#{server_url}/api/v1/applications/token" }

  let(:config_double) do
    instance_double(
      'DfE::Analytics.config',
      airbyte_client_id: client_id,
      airbyte_client_secret: client_secret,
      airbyte_server_url: server_url
    )
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.call' do
    context 'when the token API call is successful' do
      let(:token_response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          parsed_response: { 'access_token' => 'abc123' }
        )
      end

      it 'returns the access token' do
        expect(HTTParty).to receive(:post).with(
          token_url,
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          },
          body: {
            client_id: client_id,
            client_secret: client_secret,
            'grant-type': 'client_credentials'
          }.to_json
        ).and_return(token_response)

        token = described_class.call
        expect(token).to eq('abc123')
      end
    end

    context 'when the token API call fails' do
      let(:error_response) do
        instance_double(
          HTTParty::Response,
          success?: false,
          code: 401,
          body: 'unauthorized'
        )
      end

      it 'logs an error and raises an exception' do
        expect(HTTParty).to receive(:post).and_return(error_response)
        expect(Rails.logger).to receive(:error).with(
          'Error calling Airbyte token API: status: 401 body: unauthorized'
        )

        expect do
          described_class.call
        end.to raise_error(Services::Airbyte::AccessToken::Error, /status: 401/)
      end
    end
  end
end
