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

  let(:client) { instance_double(Google::Apis::BigqueryV2::BigqueryService) }
  let(:authorization) { instance_double(Object) }

  before do
    allow(DfE::Analytics.config).to receive(:azure_federated_auth).and_return(true)
    allow(Google::Apis::BigqueryV2::BigqueryService).to receive(:new).and_return(client)
    allow(DfE::Analytics::AzureFederatedAuth).to receive(:gcp_client_credentials).and_return(authorization)
    allow(client).to receive(:authorization=)
    allow(client).to receive(:authorization).and_return(authorization)
    DfE::Analytics::Testing.webmock!
  end

  describe '.client' do
    it 'raises a configuration error if required config is missing' do
      with_analytics_config(bigquery_project_id: nil) do
        expect do
          described_class.client
        end.to raise_error(DfE::Analytics::Config::ConfigurationError)
      end
    end

    it 'raises a configuration error if airbyte is enabled and airbyte config is missing' do
      with_analytics_config(test_dummy_config.merge(bigquery_airbyte_dataset: nil)) do
        allow(DfE::Analytics::Config).to receive(:airbyte_enabled?).and_return(true)

        expect do
          described_class.client
        end.to raise_error(DfE::Analytics::Config::ConfigurationError)
      end
    end

    it 'initializes and returns the BigQuery client with authorization' do
      with_analytics_config(test_dummy_config.merge(bigquery_airbyte_dataset: 'airbyte_dataset')) do
        allow(DfE::Analytics::Config).to receive(:airbyte_enabled?).and_return(true)

        expect(described_class.client).to eq(client)
      end
    end
  end

  describe '.insert' do
    subject(:insert) do
      with_analytics_config(test_dummy_config.merge(bigquery_airbyte_dataset: 'airbyte_dataset')) do
        described_class.insert([event.as_json])
      end
    end

    context 'when request is successful' do
      let(:response) { double(:response, insert_errors: []) }

      it 'does not log errors' do
        allow(client).to receive(:insert_all_table_data).and_return(response)
        expect(Rails.logger).not_to receive(:error)
        insert
      end
    end

    context 'when request has insert_errors' do
      let(:insert_error) { double(index: 0, errors: [double(message: 'Error')]) }
      let(:response) { double(insert_errors: [insert_error]) }

      before do
        allow(client).to receive(:insert_all_table_data).and_return(response)
      end

      it 'logs the error and raises SendEventsError' do
        expect(Rails.logger).to receive(:error).with(/insert error/)
        expect do
          insert
        end.to raise_error(DfE::Analytics::BigQueryApi::SendEventsError)
      end
    end
  end

  describe '.apply_policy_tags' do
    let(:dataset) { 'airbyte_dataset' }

    let(:hidden_policy_tag) do
      'projects/my-project/locations/eu/taxonomies/123/policyTags/hidden'
    end

    let(:sensitive_hidden_policy_tag) do
      'projects/my-project/locations/eu/taxonomies/123/policyTags/sensitive-hidden'
    end

    let(:policy_tags) do
      {
        hidden: hidden_policy_tag,
        sensitive_hidden: sensitive_hidden_policy_tag
      }
    end

    let(:fields) do
      [
        instance_double(Google::Apis::BigqueryV2::TableFieldSchema, name: 'email'),
        instance_double(Google::Apis::BigqueryV2::TableFieldSchema, name: 'name'),
        instance_double(Google::Apis::BigqueryV2::TableFieldSchema, name: 'created_at')
      ]
    end

    let(:schema) do
      instance_double(
        Google::Apis::BigqueryV2::TableSchema,
        fields: fields
      )
    end

    let(:table) do
      instance_double(
        Google::Apis::BigqueryV2::Table,
        schema: schema
      )
    end

    before do
      fields.each do |field|
        allow(field).to receive(:policy_tags=)
      end

      allow(client).to receive(:get_table).and_return(table)
      allow(client).to receive(:patch_table)
    end

    context 'when no policy tag is specified for the column' do
      let(:tables) do
        {
          users: %w[email name]
        }
      end

      it 'applies the hidden policy tag by default' do
        with_analytics_config(test_dummy_config) do
          described_class.apply_policy_tags(dataset, tables, policy_tags)

          expect(fields[0]).to have_received(:policy_tags=).with(
            an_object_having_attributes(names: [hidden_policy_tag])
          )

          expect(fields[1]).to have_received(:policy_tags=).with(
            an_object_having_attributes(names: [hidden_policy_tag])
          )

          expect(fields[2]).not_to have_received(:policy_tags=)
        end
      end
    end

    context 'when a policy tag is specified for a column' do
      let(:tables) do
        {
          users: [
            { 'email' => 'sensitive_hidden' },
            'name'
          ]
        }
      end

      it 'applies the specified policy tag to that column' do
        with_analytics_config(test_dummy_config) do
          described_class.apply_policy_tags(dataset, tables, policy_tags)

          expect(fields[0]).to have_received(:policy_tags=).with(
            an_object_having_attributes(names: [sensitive_hidden_policy_tag])
          )

          expect(fields[1]).to have_received(:policy_tags=).with(
            an_object_having_attributes(names: [hidden_policy_tag])
          )

          expect(fields[2]).not_to have_received(:policy_tags=)
        end
      end
    end

    it 'raises and logs error if get_table fails' do
      tables = { users: %w[email name] }

      with_analytics_config(test_dummy_config) do
        allow(client)
          .to receive(:get_table)
          .and_raise(Google::Apis::ClientError.new('not found'))

        expect(Rails.logger).to receive(:error).with(/Failed to retrieve table/)

        expect do
          described_class.apply_policy_tags(dataset, tables, policy_tags)
        end.to raise_error(DfE::Analytics::BigQueryApi::PolicyTagError)
      end
    end

    it 'raises and logs error if patch_table fails' do
      tables = { users: %w[email name] }

      with_analytics_config(test_dummy_config) do
        allow(client)
          .to receive(:patch_table)
          .and_raise(Google::Apis::ClientError.new('invalid'))

        expect(Rails.logger).to receive(:error).with(/Failed to update table/)

        expect do
          described_class.apply_policy_tags(dataset, tables, policy_tags)
        end.to raise_error(DfE::Analytics::BigQueryApi::PolicyTagError)
      end
    end
  end
end
