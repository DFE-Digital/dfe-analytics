# frozen_string_literal: true

RSpec.describe Services::Airbyte::DiscoverSchema do
  let(:access_token) { 'test-token' }
  let(:source_id) { 'source-abc' }
  let(:config_double) do
    instance_double('DfE::Analytics.config', airbyte_configuration: { source_id: source_id })
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.call' do
    let(:api_response) do
      {
        'catalog' => {
          'streams' => [{ 'name' => 'example_stream' }]
        }
      }
    end

    it 'delegates to ApiServer and returns the parsed response' do
      expect(Services::Airbyte::ApiServer).to receive(:post).with(
        path: '/api/v1/sources/discover_schema',
        access_token: access_token,
        payload: { sourceId: source_id }
      ).and_return(api_response)

      result = described_class.call(access_token:)
      expect(result).to eq(api_response)
    end

    context 'when ApiServer raises an error' do
      before do
        allow(Services::Airbyte::ApiServer).to receive(:post)
          .and_raise(Services::Airbyte::ApiServer::Error.new('Boom'))
      end

      it 'propagates the ApiServer error without wrapping' do
        expect do
          described_class.call(access_token:)
        end.to raise_error(Services::Airbyte::ApiServer::Error, /Boom/)
      end
    end
  end
end
