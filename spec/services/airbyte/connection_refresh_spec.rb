# frozen_string_literal: true

RSpec.describe Services::Airbyte::ConnectionRefresh do
  let(:token) { 'fake-token' }
  let(:connection_id) { 'connection-123' }
  let(:source_id) { 'source-456' }
  let(:schema) { { streams: [] } }
  let(:allowlist) { %w[users events] }

  before do
    allow(Services::Airbyte::AccessToken).to receive(:call).and_return(token)
    allow(Services::Airbyte::DiscoverSchema).to receive(:call).and_return(schema)
    allow(Services::Airbyte::ConnectionUpdate).to receive(:call)
    allow(DfE::Analytics).to receive(:allowlist).and_return(allowlist)
  end

  context 'when all parameters are provided' do
    it 'uses the given values and refreshes the connection' do
      described_class.call(
        access_token: token,
        connection_id: connection_id,
        source_id: source_id
      )

      expect(Services::Airbyte::DiscoverSchema).to have_received(:call).with(
        access_token: token,
        source_id: source_id
      )

      expect(Services::Airbyte::ConnectionUpdate).to have_received(:call).with(
        access_token: token,
        connection_id: connection_id,
        allowed_list: allowlist,
        discovered_schema: schema
      )
    end
  end

  context 'when access_token, connection_id, and source_id are nil' do
    let(:discovered_connection_id) { 'connection-xyz' }
    let(:discovered_source_id) { 'source-abc' }

    before do
      allow(Services::Airbyte::ConnectionList).to receive(:call)
        .with(access_token: token)
        .and_return([discovered_connection_id, discovered_source_id])
    end

    it 'fetches all values and refreshes the connection' do
      described_class.call

      expect(Services::Airbyte::AccessToken).to have_received(:call)
      expect(Services::Airbyte::ConnectionList).to have_received(:call).with(access_token: token)

      expect(Services::Airbyte::DiscoverSchema).to have_received(:call).with(
        access_token: token,
        source_id: discovered_source_id
      )

      expect(Services::Airbyte::ConnectionUpdate).to have_received(:call).with(
        access_token: token,
        connection_id: discovered_connection_id,
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
        described_class.call(
          access_token: token,
          connection_id: connection_id,
          source_id: source_id
        )
      end.to raise_error(described_class::Error, /Connection refresh failed: boom/)

      expect(Rails.logger).to have_received(:error).with(/Airbyte connection refresh failed: boom/)
    end
  end
end
