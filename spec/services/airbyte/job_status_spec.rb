# frozen_string_literal: true

require_relative '../../../lib/services/airbyte/job_status'
require_relative '../../../lib/services/airbyte/api_server'

RSpec.describe Services::Airbyte::JobStatus do
  let(:access_token) { 'token-123' }
  let(:connection_id) { 'conn-abc' }
  let(:job_id) { 'job-42' }

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

  describe '.call' do
    context 'when the job is found in the recent jobs list' do
      let(:response_body) do
        {
          'jobs' => [
            { 'id' => 'job-40', 'status' => 'running' },
            { 'id' => 'job-42', 'status' => 'succeeded' },
            { 'id' => 'job-39', 'status' => 'cancelled' }
          ]
        }
      end

      before do
        allow(Services::Airbyte::ApiServer).to receive(:post)
          .with(
            path: '/api/v1/jobs/list',
            access_token: access_token,
            payload: expected_payload
          )
          .and_return(response_body)
      end

      it 'returns the status of the matching job' do
        result = described_class.call(access_token:, connection_id:, job_id:)
        expect(result).to eq('succeeded')
      end
    end

    context 'when the job is not found in the recent jobs list' do
      let(:response_body) do
        {
          'jobs' => [
            { 'id' => 'job-40', 'status' => 'running' },
            { 'id' => 'job-41', 'status' => 'failed' }
          ]
        }
      end

      before do
        allow(Services::Airbyte::ApiServer).to receive(:post).and_return(response_body)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs an error and raises JobStatus::Error' do
        expect(Rails.logger).to receive(:error).with("Job #{job_id} not found in the last 10 jobs")

        expect do
          described_class.call(access_token:, connection_id:, job_id:)
        end.to raise_error(Services::Airbyte::JobStatus::Error, "Job #{job_id} not found in the last 10 jobs")
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(Services::Airbyte::ApiServer).to receive(:post)
          .and_raise(StandardError.new('network error'))

        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and raises JobStatus::Error' do
        expect(Rails.logger).to receive(:error).with('network error')

        expect do
          described_class.call(access_token:, connection_id:, job_id:)
        end.to raise_error(Services::Airbyte::JobStatus::Error, 'network error')
      end
    end
  end
end
