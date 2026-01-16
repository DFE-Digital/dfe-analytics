# frozen_string_literal: true

RSpec.describe Services::Airbyte::ConnectionUpdate do
  let(:access_token) { 'fake-access-token' }

  let(:allowed_list) do
    {
      academic_cycles: %w[created_at end_date id start_date updated_at]
    }
  end

  let(:connection_id) { 'abc-123' }

  let(:config_double) do
    instance_double(
      'DfE::Analytics.config',
      airbyte_configuration: { connection_id: connection_id }
    )
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.call' do
    let(:api_result) { { 'status' => 'ok' } }

    before do
      allow(Services::Airbyte::ApiServer).to receive(:patch).and_return(api_result)
    end

    it 'delegates to ApiServer.patch and returns the response' do
      result = described_class.call(
        access_token: access_token,
        allowed_list: allowed_list
      )

      expect(result).to eq(api_result)

      expect(Services::Airbyte::ApiServer).to have_received(:patch).with(
        path: "/api/public/v1/connections/#{connection_id}",
        access_token: access_token,
        payload: kind_of(Hash)
      )
    end

    it 'builds the correct connection patch payload' do
      described_class.call(
        access_token: access_token,
        allowed_list: allowed_list
      )

      expect(Services::Airbyte::ApiServer).to have_received(:patch) do |args|
        payload = args[:payload]

        expect(payload).to have_key(:configurations)
        expect(payload[:configurations]).to have_key(:streams)

        streams = payload[:configurations][:streams]
        expect(streams.size).to eq(1)

        stream = streams.first

        expect(stream[:name]).to eq('academic_cycles')
        expect(stream[:selected]).to eq(true)
        expect(stream[:syncMode]).to eq('incremental')
        expect(stream[:destinationSyncMode]).to eq('append')
        expect(stream[:cursorField]).to eq(['_ab_cdc_lsn'])
        expect(stream[:primaryKey]).to eq([['id']])

        expected_fields = %w[
          _ab_cdc_lsn
          _ab_cdc_deleted_at
          _ab_cdc_updated_at
          created_at
          end_date
          id
          start_date
          updated_at
        ].map { |f| { fieldPath: [f] } }

        expect(stream[:selectedFields]).to match_array(expected_fields)
      end
    end

    context 'when ApiServer.patch raises an error' do
      before do
        allow(Services::Airbyte::ApiServer).to receive(:patch)
          .and_raise(Services::Airbyte::ApiServer::Error, 'Boom')
      end

      it 'propagates the error' do
        expect do
          described_class.call(
            access_token: access_token,
            allowed_list: allowed_list
          )
        end.to raise_error(Services::Airbyte::ApiServer::Error, /Boom/)
      end
    end

    context 'when allowed_list is not a hash' do
      it 'raises ConnectionUpdate::Error' do
        expect do
          described_class.call(
            access_token: access_token,
            allowed_list: 'invalid'
          )
        end.to raise_error(Services::Airbyte::ConnectionUpdate::Error)
      end
    end
  end
end
