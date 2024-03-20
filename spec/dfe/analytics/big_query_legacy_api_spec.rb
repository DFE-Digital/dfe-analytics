# frozen_string_literal: true

RSpec.describe DfE::Analytics::BigQueryLegacyApi do
  let(:event) do
    {
      environment: 'test',
      request_method: 'GET',
      request_path: '/provider/applications',
      namespace: 'provider_interface',
      user_id: 3456
    }
  end

  before(:each) do
    allow(DfE::Analytics.config).to receive(:azure_federated_auth).and_return(false)

    DfE::Analytics::Testing.webmock!
  end

  describe '#events_client' do
    it 'raises a configuration error on missing config values' do
      with_analytics_config(bigquery_project_id: nil) do
        expect { described_class.events_client }.to raise_error(DfE::Analytics::BigQueryLegacyApi::ConfigurationError)
      end
    end

    context 'when authorization endpoint returns OK response' do
      let(:events_client) { double(:events_client) }

      before do
        allow(Google::Cloud::Bigquery)
          .to receive_message_chain(:new, :dataset, :table)
          .and_return(events_client)
      end

      it 'calls the expected big query apis' do
        with_analytics_config(test_dummy_config) do
          expect(described_class.events_client).to eq(events_client)
        end
      end
    end
  end

  describe '#insert' do
    subject(:insert) { described_class.insert([event.as_json]) }

    context 'when the request is successful' do
      it 'does not log the request when event_debug disabled' do
        stub_analytics_event_submission

        expect(Rails.logger).not_to receive(:info)

        insert
      end

      it 'sends the events JSON to Bigquery' do
        request = stub_analytics_event_submission

        insert

        expect(request.with do |req|
          body = JSON.parse(req.body)
          payload = body['rows'].first['json']
          expect(payload.except('occurred_at', 'request_uuid')).to match(a_hash_including(event.deep_stringify_keys))
        end).to have_been_made
      end
    end

    context 'when the request is not successful' do
      before { stub_analytics_event_submission_with_insert_errors }

      it 'raises an exception' do
        expect { insert }.to raise_error(DfE::Analytics::BigQueryLegacyApi::SendEventsError, /An error./)
      end

      it 'contains the insert errors' do
        insert
      rescue DfE::Analytics::BigQueryLegacyApi::SendEventsError => e
        expect(e.message).to_not be_empty
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:error).with(/DfE::Analytics BigQuery API insert error for 1 event\(s\):/)

        insert
      rescue DfE::Analytics::BigQueryLegacyApi::SendEventsError
        nil
      end
    end
  end
end
