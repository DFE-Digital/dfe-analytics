# frozen_string_literal: true

RSpec.describe DfE::Analytics::AzureFederatedAuth do
  before(:each) do
    allow(DfE::Analytics.config).to receive(:azure_federated_auth).and_return(true)

    DfE::Analytics::Testing.webmock!
  end

  let(:azure_access_token) { 'fake_az_response_token' }
  let(:azure_google_exchange_access_token) { 'fake_az_gcp_exchange_token_response' }
  let(:google_access_token) { 'fake_google_response_token' }
  let(:google_access_token_expire_time) { '2024-03-09T14:38:02Z' }

  describe '#azure_access_token' do
    before do
      allow(File).to receive(:read).with('fake_az_token_path').and_return('fake_az_token')
    end

    context 'when azure access token endpoint returns OK response' do
      it 'returns the access token' do
        stub_azure_access_token_request

        expect(described_class.azure_access_token).to eq(azure_access_token)
      end
    end

    context 'when azure access token endpoint returns an error response' do
      it 'raises the expected error' do
        stub_azure_access_token_request_with_auth_error

        expected_err_msg = /Error calling azure token API: status: 400/

        expect(Rails.logger).to receive(:error).with(expected_err_msg)

        expect { described_class.azure_access_token }
          .to raise_error(DfE::Analytics::AzureFederatedAuth::Error, expected_err_msg)
      end
    end
  end

  describe '#azure_google_exchange_access_token' do
    context 'when google exchange access token endpoint returns OK response' do
      it 'returns the access token' do
        stub_azure_google_exchange_access_token_request

        expect(described_class.azure_google_exchange_access_token(azure_access_token))
          .to eq(azure_google_exchange_access_token)
      end
    end

    context 'when google exchange access token endpoint returns an error response' do
      it 'raises the expected error' do
        stub_azure_google_exchange_access_token_request_with_auth_error

        expected_err_msg = /Error calling google exchange token API: status: 400/

        expect(Rails.logger).to receive(:error).with(expected_err_msg)

        expect { described_class.azure_google_exchange_access_token(azure_access_token) }
          .to raise_error(DfE::Analytics::AzureFederatedAuth::Error, expected_err_msg)
      end
    end
  end

  describe '#google_access_token' do
    context 'when google access token endpoint returns OK response' do
      it 'returns the access token' do
        stub_google_access_token_request

        expect(described_class.google_access_token(azure_google_exchange_access_token))
          .to eq([google_access_token, google_access_token_expire_time])
      end
    end

    context 'when google access token endpoint returns an error response' do
      it 'raises the expected error' do
        stub_google_access_token_request_with_auth_error

        expected_err_msg = /Error calling google token API: status: 401/

        expect(Rails.logger).to receive(:error).with(expected_err_msg)

        expect { described_class.google_access_token(azure_google_exchange_access_token) }
          .to raise_error(DfE::Analytics::AzureFederatedAuth::Error, expected_err_msg)
      end
    end
  end

  describe '#gcp_client_credentials' do
    let(:future_expire_time) { Time.now + 1.hour }

    before do
      allow(described_class).to receive(:azure_access_token).and_return(azure_access_token)

      allow(described_class)
        .to receive(:azure_google_exchange_access_token)
        .with(azure_access_token).and_return(azure_google_exchange_access_token)

      allow(described_class)
        .to receive(:google_access_token)
        .with(azure_google_exchange_access_token).and_return([google_access_token, future_expire_time])
    end

    it 'returns the expected client credentials' do
      expect(described_class.gcp_client_credentials).to be_an_instance_of(Google::Auth::UserRefreshCredentials)
      expect(described_class.gcp_client_credentials.access_token).to eq(google_access_token)
      expect(described_class.gcp_client_credentials.expires_at)
        .to be_within(DfE::Analytics::AzureFederatedAuth::ACCESS_TOKEN_EXPIRE_TIME_LEEWAY).of(future_expire_time)
    end

    context 'token expiry' do
      context 'when expire time is in the future' do
        it 'calls token APIs once only on mutiple calls to get access token' do
          expect(described_class)
            .to receive(:azure_access_token)
            .and_return(azure_access_token)
            .once

          expect(described_class)
            .to receive(:azure_google_exchange_access_token)
            .with(azure_access_token)
            .and_return(azure_google_exchange_access_token)
            .once

          expect(described_class)
            .to receive(:google_access_token)
            .with(azure_google_exchange_access_token)
            .and_return([google_access_token, future_expire_time])
            .once

          5.times do
            expect(described_class.gcp_client_credentials.access_token).to eq(google_access_token)
          end
        end
      end

      context 'when the token expires on every call' do
        it 'calls token APIs everytime there is a call to get access token' do
          expect(described_class)
            .to receive(:azure_access_token)
            .and_return(azure_access_token)
            .exactly(5)
            .times

          expect(described_class)
            .to receive(:azure_google_exchange_access_token)
            .with(azure_access_token)
            .and_return(azure_google_exchange_access_token)
            .exactly(5)
            .times

          expect(described_class)
            .to receive(:google_access_token)
            .with(azure_google_exchange_access_token)
            .and_return([google_access_token, Time.now])
            .exactly(5)
            .times

          5.times do
            expect(described_class.gcp_client_credentials.access_token).to eq(google_access_token)
          end
        end
      end
    end
  end
end
