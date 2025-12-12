# frozen_string_literal: true

RSpec.describe Services::Airbyte::JobLast do
  let(:access_token) { 'test-token' }
  let(:job_data) { { 'id' => 'job-1', 'status' => 'succeeded' } }

  let(:expected_payload) do
    {
      configTypes: ['sync'],
      configId: connection_id,
      pagination: {
        pageSize: described_class::PAGE_SIZE,
        rowOffset: 0
      }
    }
  end

  let(:connection_id) { 'conn-123' }
  let(:config_double) do
    instance_double('DfE::Analytics.config', airbyte_configuration: { connection_id: connection_id })
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '.call' do
    context 'when API returns jobs' do
      let(:response_body) { { 'jobs' => [job_data] } }

      before do
        allow(Services::Airbyte::ApiServer).to receive(:post)
          .with(
            path: '/api/v1/jobs/list',
            access_token: access_token,
            payload: expected_payload
          ).and_return(response_body)
      end

      it 'returns the first job' do
        result = described_class.call(access_token:)

        expect(result).to eq(job_data)
        expect(Services::Airbyte::ApiServer).to have_received(:post)
      end
    end

    context 'when API returns no jobs' do
      before do
        allow(Services::Airbyte::ApiServer).to receive(:post)
          .and_return({ 'jobs' => [] })
      end

      it 'returns nil' do
        result = described_class.call(access_token:)
        expect(result).to be_nil
      end
    end

    context 'when API call fails' do
      before do
        allow(Services::Airbyte::ApiServer).to receive(:post)
          .and_raise(StandardError, 'some API error')

        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and raises JobLast::Error' do
        expect(Rails.logger).to receive(:error).with('some API error')

        expect do
          described_class.call(access_token:)
        end.to raise_error(Services::Airbyte::JobLast::Error, 'some API error')
      end
    end
  end
end
