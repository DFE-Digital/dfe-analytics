# frozen_string_literal: true

require_relative '../../../lib/services/airbyte/start_sync'
require_relative '../../../lib/services/airbyte/api_server'

RSpec.describe Services::Airbyte::StartSync do
  let(:access_token) { 'access-token-123' }
  let(:connection_id) { 'conn-abc-456' }
  let(:job_id) { 'job-789' }

  describe '.call' do
    context 'when the API returns a job ID' do
      let(:response_body) { { 'job' => { 'id' => job_id } } }

      before do
        allow(Services::Airbyte::ApiServer).to receive(:post).with(
          path: '/api/v1/connections/sync',
          access_token: access_token,
          payload: { connectionId: connection_id }
        ).and_return(response_body)
      end

      it 'returns the job ID' do
        result = described_class.call(access_token:, connection_id:)
        expect(result).to eq(job_id)
      end
    end

    context 'when the API does not return a job ID' do
      let(:response_body) { { 'job' => nil } }

      before do
        allow(Services::Airbyte::ApiServer).to receive(:post).and_return(response_body)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs and raises a StartSync::Error' do
        expect(Rails.logger).to receive(:error).with(/StartSync failed: No job ID returned/)

        expect do
          described_class.call(access_token:, connection_id:)
        end.to raise_error(Services::Airbyte::StartSync::Error, /No job ID returned/)
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(Services::Airbyte::ApiServer).to receive(:post).and_raise(StandardError.new('timeout'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs and raises a StartSync::Error' do
        expect(Rails.logger).to receive(:error).with(/StartSync failed: timeout/)

        expect do
          described_class.call(access_token:, connection_id:)
        end.to raise_error(Services::Airbyte::StartSync::Error, /timeout/)
      end
    end
  end
end
