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
    allow(Services::Airbyte::DiscoverSchema).to receive(:call).and_return(discovered_schema)
    allow(Services::Airbyte::ConnectionUpdate).to receive(:call)
  end

  describe '.call' do
    it 'calls the instance method' do
      instance = instance_double(described_class)
      expect(described_class).to receive(:new).and_return(instance)
      expect(instance).to receive(:call)
      described_class.call
    end
  end

  describe '#call' do
    subject(:service) { described_class.new }

    context 'when all arguments are provided' do
      it 'skips fetching access_token and connection_id/source_id' do
        expect(Services::Airbyte::AccessToken).not_to receive(:call)
        expect(Services::Airbyte::ConnectionList).not_to receive(:call)
        expect(Services::Airbyte::DiscoverSchema).to receive(:call).with(access_token:, source_id:)
        expect(Services::Airbyte::ConnectionUpdate).to receive(:call).with(
          access_token: access_token,
          connection_id: connection_id,
          allowed_list: allowed_list,
          discovered_schema: discovered_schema
        )

        service.call(access_token:, connection_id:, source_id:)
      end
    end

    context 'when only access_token is provided' do
      before do
        allow(Services::Airbyte::ConnectionList).to receive(:call)
          .with(access_token:).and_return([connection_id, source_id])
      end

      it 'fetches connection_id and source_id' do
        expect(Services::Airbyte::ConnectionList).to receive(:call).with(access_token:)
        expect(Services::Airbyte::DiscoverSchema).to receive(:call).with(access_token:, source_id:)
        expect(Services::Airbyte::ConnectionUpdate).to receive(:call).with(
          access_token: access_token,
          connection_id: connection_id,
          allowed_list: allowed_list,
          discovered_schema: discovered_schema
        )

        service.call(access_token:)
      end
    end

    context 'when no arguments are provided' do
      before do
        allow(Services::Airbyte::AccessToken).to receive(:call).and_return(access_token)
        allow(Services::Airbyte::ConnectionList).to receive(:call)
          .with(access_token:).and_return([connection_id, source_id])
      end

      it 'calls all dependency services' do
        expect(Services::Airbyte::AccessToken).to receive(:call)
        expect(Services::Airbyte::ConnectionList).to receive(:call).with(access_token:)
        expect(Services::Airbyte::DiscoverSchema).to receive(:call).with(access_token:, source_id:)
        expect(Services::Airbyte::ConnectionUpdate).to receive(:call).with(
          access_token: access_token,
          connection_id: connection_id,
          allowed_list: allowed_list,
          discovered_schema: discovered_schema
        )

        service.call
      end
    end

    context 'when an error occurs in any step' do
      before do
        allow(Services::Airbyte::AccessToken).to receive(:call).and_raise(StandardError, 'boom')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and raises wrapped error' do
        expect(Rails.logger).to receive(:error).with(/Airbyte connection refresh failed: boom/)

        expect do
          service.call
        end.to raise_error(Services::Airbyte::ConnectionRefresh::Error, /Connection refresh failed: boom/)
      end
    end
  end
end
