# frozen_string_literal: true

RSpec.describe Services::Airbyte::ConnectionRefresh do
  let(:token) { 'fake-token' }
  let(:schema) { { streams: [] } }
  let(:allowlist) { %w[users events] }
  let(:connection_id) { 'connection-123' }

  let(:config_double) do
    instance_double('DfE::Analytics.config', airbyte_configuration: { connection_id: connection_id })
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  before do
    allow(Services::Airbyte::AccessToken).to receive(:call).and_return(token)
    allow(Services::Airbyte::DiscoverSchema).to receive(:call).and_return(schema)
    allow(Services::Airbyte::ConnectionUpdate).to receive(:call)
    allow(DfE::Analytics).to receive(:allowlist).and_return(allowlist)
  end

  context 'when all parameters are provided' do
    it 'uses the given values and refreshes the connection' do
      described_class.call(access_token: token)

      expect(Services::Airbyte::DiscoverSchema).to have_received(:call).with(
        access_token: token
      )

      expect(Services::Airbyte::ConnectionUpdate).to have_received(:call).with(
        access_token: token,
        allowed_list: allowlist,
        discovered_schema: schema
      )
    end
  end

  context 'when an error occurs' do
    before do
      allow(Services::Airbyte::DiscoverSchema).to receive(:call)
        .and_raise(StandardError.new('boom'))
      allow(Rails.logger).to receive(:error)
    end

    it 'raises a wrapped ConnectionRefresh::Error and logs the error' do
      expect do
        described_class.call(access_token: token)
      end.to raise_error(described_class::Error, /Connection refresh failed: boom/)

      expect(Rails.logger).to have_received(:error).with(/Airbyte connection refresh failed: boom/)
    end
  end
end
