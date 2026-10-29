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
end
