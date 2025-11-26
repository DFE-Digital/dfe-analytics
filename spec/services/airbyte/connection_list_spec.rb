# frozen_string_literal: true

RSpec.describe Services::Airbyte::ConnectionList do
  let(:access_token) { 'mock-access-token' }
  let(:workspace_id) { 'workspace-123' }
  let(:config_double) do
    instance_double('DfE::Analytics.config', airbyte_workspace_id: workspace_id)
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.call' do
    subject(:call_result) { described_class.call(access_token:) }

    context 'when the API returns a connection' do
      let(:mock_response) do
        {
          'connections' => [
            {
              'connectionId' => 'conn-1',
              'sourceId' => 'src-1'
            }
          ]
        }
      end

      before do
        allow(Services::Airbyte::ApiServer).to receive(:post).and_return(mock_response)
      end

      it 'returns connectionId and sourceId as an array' do
        expect(call_result).to eq(%w[conn-1 src-1])

        expect(Services::Airbyte::ApiServer).to have_received(:post).with(
          path: '/api/v1/connections/list',
          access_token:,
          payload: { workspaceId: workspace_id }
        )
      end
    end

    context 'when the API returns no connections' do
      let(:mock_response) { { 'connections' => [] } }

      before do
        allow(Services::Airbyte::ApiServer).to receive(:post).and_return(mock_response)
      end

      it 'raises a ConnectionList::Error' do
        expect do
          call_result
        end.to raise_error(described_class::Error, /No connections returned/)
      end
    end

    context 'when the API call raises an ApiServer::Error' do
      before do
        allow(Services::Airbyte::ApiServer).to receive(:post)
          .and_raise(Services::Airbyte::ApiServer::Error.new('something exploded'))
      end

      it 'raises the same ApiServer::Error (not caught here)' do
        expect do
          call_result
        end.to raise_error(Services::Airbyte::ApiServer::Error, /something exploded/)
      end
    end
  end
end
