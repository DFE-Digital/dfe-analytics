# frozen_string_literal: true

RSpec.describe DfE::Analytics::AirbyteDeployJob do
  let(:access_token) { 'fake-token' }
  let(:connection_id) { 'conn-123' }
  let(:source_id) { 'source-abc' }
  let(:job_id) { 456 }
  let(:running_job) { { 'status' => 'running', 'id' => job_id } }
  let(:finished_job) { { 'status' => 'succeeded', 'id' => job_id } }

  before do
    allow(DfE::Analytics::Services::WaitForMigrations).to receive(:call)
    allow(Services::Airbyte::AccessToken).to receive(:call).and_return(access_token)
    allow(Services::Airbyte::ConnectionList).to receive(:call).and_return([connection_id, source_id])
    allow(Services::Airbyte::ConnectionRefresh).to receive(:call)
    allow(Services::Airbyte::JobLast).to receive(:call).and_return(nil)
    allow(Services::Airbyte::StartSync).to receive(:call).and_return(job_id)
    allow(Services::Airbyte::WaitForSync).to receive(:call).and_return('succeeded')
    allow(DfE::Analytics::BigQueryApplyPolicyTagsJob).to receive(:perform_later)
  end

  it 'calls all Airbyte orchestration steps in order' do
    described_class.new.perform

    expect(DfE::Analytics::Services::WaitForMigrations).to have_received(:call)
    expect(Services::Airbyte::AccessToken).to have_received(:call)
    expect(Services::Airbyte::ConnectionList).to have_received(:call).with(access_token: access_token)
    expect(Services::Airbyte::ConnectionRefresh).to have_received(:call).with(
      access_token: access_token,
      connection_id: connection_id,
      source_id: source_id
    )
    expect(Services::Airbyte::StartSync).to have_received(:call).with(
      access_token: access_token,
      connection_id: connection_id
    )
    expect(Services::Airbyte::WaitForSync).to have_received(:call).with(
      access_token: access_token,
      connection_id: connection_id,
      job_id: job_id
    )
    expect(DfE::Analytics::BigQueryApplyPolicyTagsJob).to have_received(:perform_later)
  end

  context 'when last job is running' do
    before do
      allow(Services::Airbyte::JobLast).to receive(:call).and_return(running_job)
      allow(Services::Airbyte::StartSync).to receive(:call) # should not be called
    end

    it 'does not call StartSync but waits on existing job' do
      described_class.new.perform

      expect(Services::Airbyte::StartSync).not_to have_received(:call)
      expect(Services::Airbyte::WaitForSync).to have_received(:call).with(
        access_token: access_token,
        connection_id: connection_id,
        job_id: job_id
      )
    end
  end

  context 'when an error occurs in orchestration' do
    before do
      allow(Services::Airbyte::AccessToken).to receive(:call).and_raise(StandardError, 'Boom!')
      allow(Rails.logger).to receive(:error)
    end

    it 'logs the error and raises a wrapped exception' do
      expect do
        described_class.new.perform
      end.to raise_error(RuntimeError, /AirbyteDeployJob failed: Boom!/)

      expect(Rails.logger).to have_received(:error).with('Boom!')
    end
  end
end
