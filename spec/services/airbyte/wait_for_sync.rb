# frozen_string_literal: true

RSpec.describe Services::Airbyte::WaitForSync do
  let(:access_token) { 'mock-token' }
  let(:connection_id) { 'conn-123' }
  let(:job_id) { 'job-456' }

  describe '.call' do
    subject(:call) do
      described_class.call(access_token:, connection_id:, job_id:)
    end

    before do
      allow(Kernel).to receive(:sleep) # avoid actual sleeping
    end

    context 'when the job eventually succeeds' do
      before do
        allow(Services::Airbyte::JobStatus).to receive(:call)
          .with(access_token:, connection_id:, job_id:)
          .and_return('running', 'running', 'succeeded')
      end

      it 'returns "succeeded"' do
        expect(call).to eq('succeeded')
      end
    end

    context 'when the job fails' do
      before do
        allow(Services::Airbyte::JobStatus).to receive(:call)
          .and_return('failed')
      end

      it 'raises a WaitForSync::Error with failure message' do
        expect do
          call
        end.to raise_error(described_class::Error, /failed with status: failed/)
      end
    end

    context 'when the job times out' do
      before do
        allow(Services::Airbyte::JobStatus).to receive(:call).and_return('running')
        allow(Time).to receive(:now).and_return(*Array.new(100) { |i| Time.at(i * 40) }) # simulates time increasing
      end

      it 'raises a WaitForSync::Error due to timeout' do
        expect do
          call
        end.to raise_error(described_class::Error, /Timed out/)
      end
    end

    context 'when JobStatus raises an unexpected error' do
      before do
        allow(Services::Airbyte::JobStatus).to receive(:call).and_raise(StandardError.new('network error'))
      end

      it 'raises a WaitForSync::Error wrapping the original error' do
        expect do
          call
        end.to raise_error(described_class::Error, /network error/)
      end
    end
  end
end
