# frozen_string_literal: true

require_relative '../../../lib/services/airbyte/connection_refresh'
require_relative '../../../lib/services/airbyte/access_token'
require_relative '../../../lib/services/airbyte/connection_list'
require_relative '../../../lib/services/airbyte/discover_schema'
require_relative '../../../lib/services/airbyte/connection_update'

RSpec.describe Services::Airbyte::ConnectionRefresh do
  let(:access_token) { 'mock-token' }
  let(:connection_id) { 'connection-123' }
  let(:source_id) { 'source-abc' }
  let(:discovered_schema) { { 'catalog' => { 'streams' => [] } } }
  let(:allowed_list) { { academic_cycles: %w[created_at id] } }

  before do
    allow(DfE::Analytics).to receive(:allowlist).and_return(allowed_list)

    allow(Services::Airbyte::AccessToken).to receive(:call).and_return(access_token)
    allow(Services::Airbyte::ConnectionList).to receive(:call)
      .with(access_token: access_token)
      .and_return([connection_id, source_id])
    allow(Services::Airbyte::DiscoverSchema).to receive(:call)
      .with(access_token: access_token, source_id: source_id)
      .and_return(discovered_schema)
    allow(Services::Airbyte::ConnectionUpdate).to receive(:call)
  end

  it 'refreshes the connection by calling required services' do
    expect(Services::Airbyte::AccessToken).to receive(:call)
    expect(Services::Airbyte::ConnectionList).to receive(:call).with(access_token: access_token)
    expect(Services::Airbyte::DiscoverSchema).to receive(:call).with(access_token: access_token, source_id: source_id)
    expect(Services::Airbyte::ConnectionUpdate).to receive(:call).with(
      access_token: access_token,
      connection_id: connection_id,
      allowed_list: allowed_list,
      discovered_schema: discovered_schema
    )

    described_class.call
  end

  context 'when an error occurs during processing' do
    before do
      allow(Services::Airbyte::AccessToken).to receive(:call).and_raise(StandardError, 'something went wrong')
      allow(Rails.logger).to receive(:error)
    end

    it 'logs and raises a ConnectionRefresh error' do
      expect(Rails.logger).to receive(:error).with(/Airbyte connection refresh failed: something went wrong/)
      expect { described_class.call }.to raise_error(Services::Airbyte::ConnectionRefresh::Error, /Connection refresh failed/)
    end
  end
end
