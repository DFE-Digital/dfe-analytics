# frozen_string_literal: true

RSpec.describe DfE::Analytics::BigQueryApi do
  let(:event) do
    {
      environment: 'test',
      request_method: 'GET',
      request_path: '/provider/applications',
      namespace: 'provider_interface',
      user_id: 3456
    }
  end

  let(:events_client) { double(:events_client) }
  let(:authorization) { double(:authorization) }

  before(:each) do
    allow(DfE::Analytics.config).to receive(:azure_federated_auth).and_return(true)

    allow(Google::Apis::BigqueryV2::BigqueryService).to receive(:new).and_return(events_client)
    allow(DfE::Analytics::AzureFederatedAuth).to receive(:gcp_client_credentials).and_return(authorization)
    allow(events_client).to receive(:authorization=).and_return(authorization)

    DfE::Analytics::Testing.webmock!
  end

  describe '#events_client' do
    it 'raises a configuration error on missing config values' do
      with_analytics_config(bigquery_project_id: nil) do
        expect { described_class.events_client }.to raise_error(DfE::Analytics::BigQueryApi::ConfigurationError)
      end
    end

    context 'when authorization endpoint returns OK response' do
      it 'calls the expected big query apis' do
        with_analytics_config(test_dummy_config) do
          expect(described_class.events_client).to eq(events_client)
        end
      end
    end
  end

  describe '#insert' do
    subject(:insert) do
      with_analytics_config(test_dummy_config) do
        described_class.insert([event.as_json])
      end
    end

    context 'when the request is successful' do
      let(:response) { double(:response, insert_errors: []) }

      it 'does not log the request when event_debug disabled' do
        allow(events_client).to receive(:insert_all_table_data).and_return(response)
        expect(Rails.logger).not_to receive(:info)

        insert
      end

      it 'calls the expected big query apis' do
        expect(events_client).to receive(:insert_all_table_data)
          .with(
            test_dummy_config[:bigquery_project_id],
            test_dummy_config[:bigquery_dataset],
            test_dummy_config[:bigquery_table_name],
            an_instance_of(Google::Apis::BigqueryV2::InsertAllTableDataRequest),
            options: an_instance_of(Google::Apis::RequestOptions)
          )
          .and_return(response)

        insert
      end
    end

    context 'when the request is not successful' do
      let(:response) { double(:response, insert_errors: [insert_error]) }
      let(:insert_error) { double(:insert_error, index: 0, errors: [error]) }
      let(:error) { double(:error, message: 'An error.') }

      before { expect(events_client).to receive(:insert_all_table_data).and_return(response) }

      it 'raises an exception' do
        expect { insert }.to raise_error(DfE::Analytics::BigQueryApi::SendEventsError, /An error./)
      end

      it 'contains the insert errors' do
        insert
      rescue DfE::Analytics::BigQueryApi::SendEventsError => e
        expect(e.message).to_not be_empty
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:error).with(/DfE::Analytics BigQuery API insert error for 1 event\(s\):/)

        insert
      rescue DfE::Analytics::BigQueryApi::SendEventsError
        nil
      end
    end
  end
end
