# frozen_string_literal: true

RSpec.describe Services::Airbyte::ConnectionUpdate do
  let(:access_token) { 'fake-access-token' }
  let(:connection_id) { 'abc-123' }

  let(:config_double) do
    instance_double(
      'DfE::Analytics.config',
      airbyte_configuration: { connection_id: connection_id }
    )
  end

  let(:airbyte_stream_config) do
    {
      configurations: {
        streams: [
          {
            name: 'academic_cycles',
            syncMode: 'incremental_append',
            cursorField: ['_ab_cdc_lsn'],
            primaryKey: [['id']],
            selectedFields: [
              { fieldPath: ['_ab_cdc_lsn'] },
              { fieldPath: ['_ab_cdc_deleted_at'] },
              { fieldPath: ['_ab_cdc_updated_at'] },
              { fieldPath: ['created_at'] },
              { fieldPath: ['end_date'] },
              { fieldPath: ['id'] },
              { fieldPath: ['start_date'] },
              { fieldPath: ['updated_at'] }
            ]
          },
          {
            name: 'airbyte_heartbeat',
            syncMode: 'full_refresh_overwrite',
            primaryKey: [['id']],
            selectedFields: [
              { fieldPath: ['id'] },
              { fieldPath: ['last_heartbeat'] }
            ]
          }
        ]
      }
    }
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
    allow(DfE::Analytics).to receive(:airbyte_stream_config).and_return(airbyte_stream_config)
  end

  describe '.call' do
    let(:api_result) { { 'status' => 'ok' } }

    before do
      allow(Services::Airbyte::ApiServer).to receive(:patch).and_return(api_result)
    end

    it 'delegates to ApiServer.patch and returns the response' do
      result = described_class.call(access_token: access_token)

      expect(result).to eq(api_result)

      expect(Services::Airbyte::ApiServer).to have_received(:patch).with(
        path: "/api/public/v1/connections/#{connection_id}",
        access_token: access_token,
        payload: airbyte_stream_config
      )
    end

    it 'uses DfE::Analytics.airbyte_stream_config as the payload' do
      described_class.call(access_token: access_token)

      expect(DfE::Analytics).to have_received(:airbyte_stream_config)
      expect(Services::Airbyte::ApiServer).to have_received(:patch) do |args|
        expect(args[:payload]).to eq(airbyte_stream_config)
      end
    end

    context 'when ApiServer.patch raises an error' do
      before do
        allow(Services::Airbyte::ApiServer).to receive(:patch)
          .and_raise(Services::Airbyte::ApiServer::Error, 'Boom')
      end

      it 'propagates the error' do
        expect do
          described_class.call(access_token: access_token)
        end.to raise_error(Services::Airbyte::ApiServer::Error, /Boom/)
      end
    end
  end
end
