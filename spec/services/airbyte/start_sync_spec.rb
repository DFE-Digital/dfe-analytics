# frozen_string_literal: true

RSpec.describe Services::Airbyte::StartSync do
  let(:access_token)   { 'fake-token' }
  let(:connection_id)  { 'conn-123' }
  let(:job_id)         { 999 }
  let(:payload)        { { connectionId: connection_id } }

  describe '.call' do
    subject(:call_service) { described_class.call(access_token:, connection_id:) }

    before do
      allow(Services::Airbyte::ApiServer).to receive(:post)
      allow(Services::Airbyte::JobLast).to receive(:call)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    context 'when sync starts successfully' do
      let(:success_response) { { 'job' => { 'id' => job_id } } }

      before do
        allow(Services::Airbyte::ApiServer)
          .to receive(:post)
          .with(path: '/api/v1/connections/sync', access_token:, payload:)
          .and_return(success_response)
      end

      it 'returns the job id from response' do
        expect(call_service).to eq(job_id)
      end
    end

    context 'when API returns success but no job id' do
      let(:empty_response) { { 'job' => {} } }

      before do
        allow(Services::Airbyte::ApiServer)
          .to receive(:post)
          .and_return(empty_response)
      end

      it 'raises StartSync::Error' do
        expect { call_service }.to raise_error(described_class::Error, /No job ID/)
      end
    end

    context 'when a sync is already running (HTTP 409)' do
      before do
        allow(Services::Airbyte::ApiServer)
          .to receive(:post)
          .and_raise(Services::Airbyte::ApiServer::HttpError.new(409, 'Conflict'))

        allow(Services::Airbyte::JobLast)
          .to receive(:call)
          .with(access_token:, connection_id:)
          .and_return({ 'job' => { 'id' => job_id } })
      end

      it 'logs an info message and returns the last job id' do
        expect(call_service).to eq(job_id)

        expect(Rails.logger).to have_received(:info)
          .with('Sync already in progress, retrieving last job instead.')
      end
    end

    context 'when a 409 occurs but last job has no id' do
      before do
        allow(Services::Airbyte::ApiServer)
          .to receive(:post)
          .and_raise(Services::Airbyte::ApiServer::HttpError.new(409, 'Conflict'))

        allow(Services::Airbyte::JobLast)
          .to receive(:call)
          .and_return({})
      end

      it 'raises StartSync::Error' do
        expect { call_service }.to raise_error(described_class::Error, /No job ID/)
      end
    end

    context 'when HTTP error is not 409' do
      before do
        allow(Services::Airbyte::ApiServer)
          .to receive(:post)
          .and_raise(Services::Airbyte::ApiServer::HttpError.new(500, 'Boom'))
      end

      it 're-raises the error and does not swallow it' do
        expect { call_service }.to raise_error(Services::Airbyte::ApiServer::HttpError)
      end
    end

    context 'when another StandardError occurs' do
      before do
        allow(Services::Airbyte::ApiServer)
          .to receive(:post)
          .and_raise(StandardError.new('exploded'))
      end

      it 'logs the error and raises a wrapped StartSync::Error' do
        expect do
          call_service
        end.to raise_error(described_class::Error, /exploded/)

        expect(Rails.logger).to have_received(:error).with(/StartSync failed: exploded/)
      end
    end
  end
end
