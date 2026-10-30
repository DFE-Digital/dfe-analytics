# frozen_string_literal: true

RSpec.describe DfE::Analytics::AzureFederatedAuth do
  before do
    allow(DfE::Analytics.config).to receive(:azure_federated_auth).and_return(true)
    allow(DfE::Analytics.config).to receive(:azure_client_id).and_return('fake_az_client_id_1234')
    allow(DfE::Analytics.config).to receive(:azure_scope).and_return('fake_az_scope')
    allow(DfE::Analytics.config).to receive(:azure_token_path).and_return('fake_az_token_path')
    allow(DfE::Analytics.config).to receive(:gcp_scope).and_return('fake_gcp_scope')
    allow(DfE::Analytics.config).to receive(:google_cloud_credentials).and_return(
      {
        audience: 'fake_audience',
        subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
        token_url: 'https://sts.googleapis.com/v1/token',
        service_account_impersonation_url:
          'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/fake:generateAccessToken',
        credential_source: {
          url: 'https://login.microsoftonline.com/fake-az-token-id/oauth2/v2.0/token'
        }
      }
    )

    DfE::Analytics::Testing.webmock!
  end

  describe '.gcp_client_credentials' do
    it 'returns external account credentials' do
      credentials = described_class.gcp_client_credentials

      expect(credentials).to be_an_instance_of(described_class)
      expect(credentials).to be_a(Google::Auth::ExternalAccount::IdentityPoolCredentials)
    end

    it 'reuses the credentials instance' do
      credentials = described_class.gcp_client_credentials

      expect(described_class.gcp_client_credentials).to equal(credentials)
    end
  end

  describe '#retrieve_subject_token!' do
    before do
      allow(File).to receive(:read).with('fake_az_token_path').and_return('fake_az_token')
    end

    context 'when azure access token endpoint returns OK response' do
      it 'returns the access token' do
        stub_azure_access_token_request

        expect(described_class.gcp_client_credentials.retrieve_subject_token!)
          .to eq('fake_az_response_token')
      end
    end

    context 'when azure access token endpoint returns an error response' do
      it 'raises the expected error' do
        stub_azure_access_token_request_with_auth_error

        expected_err_msg = /Error calling azure token API: status: 400/

        expect(Rails.logger).to receive(:error).with(expected_err_msg)

        expect { described_class.gcp_client_credentials.retrieve_subject_token! }
          .to raise_error(described_class::Error, expected_err_msg)
      end
    end
  end

  describe 'Google workload identity federation' do
    let(:sts_access_token) { 'fake_sts_access_token' }
    let(:google_access_token) { 'fake_google_access_token' }

    before do
      allow(File).to receive(:read).with('fake_az_token_path').and_return('fake_az_token')

      stub_azure_access_token_request

      stub_request(:post, 'https://sts.googleapis.com/v1/token')
        .with do |request|
          body = URI.decode_www_form(request.body).to_h

          body['grant_type'] == 'urn:ietf:params:oauth:grant-type:token-exchange' &&
            body['audience'] == 'fake_audience' &&
            body['scope'] == 'https://www.googleapis.com/auth/iam' &&
            body['requested_token_type'] == 'urn:ietf:params:oauth:token-type:access_token' &&
            body['subject_token'] == 'fake_az_response_token' &&
            body['subject_token_type'] == 'urn:ietf:params:oauth:token-type:jwt'
        end
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            access_token: sts_access_token,
            issued_token_type: 'urn:ietf:params:oauth:token-type:access_token',
            token_type: 'Bearer',
            expires_in: 3600
          }.to_json
        )

      stub_request(
        :post,
        'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/fake:generateAccessToken'
      )
        .with do |request|
          request.headers['Authorization'] == "Bearer #{sts_access_token}" &&
            JSON.parse(request.body)['scope'] == 'fake_gcp_scope'
        end
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            accessToken: google_access_token,
            expireTime: (Time.now.utc + 1.hour).iso8601
          }.to_json
        )
    end

    it 'uses googleauth to exchange the Entra token and impersonate the service account' do
      credentials = described_class.gcp_client_credentials

      credentials.fetch_access_token!

      expect(credentials.access_token).to eq(google_access_token)

      expect(
        a_request(:post, 'https://sts.googleapis.com/v1/token')
      ).to have_been_made.once

      expect(
        a_request(
          :post,
          'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/fake:generateAccessToken'
        )
      ).to have_been_made.once
    end
  end
end
