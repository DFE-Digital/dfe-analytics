# frozen_string_literal: true

RSpec.describe DfE::Analytics::Config do
  describe '.params' do
    it 'returns a struct with all configurable keys' do
      config = described_class.params
      expect(config).to be_a(Struct)
      expect(described_class::CONFIGURABLES).to all(satisfy { |key| config.members.include?(key) })
    end
  end

  describe '.configure' do
    let(:config) { described_class.params }

    context 'when minimal configuration is given' do
      before { described_class.configure(config) }

      it 'sets sane defaults for booleans and procs' do
        expect(config.enable_analytics.call).to eq(true)
        expect(config.log_only).to eq(false)
        expect(config.async).to eq(true)
        expect(config.queue).to eq(:default)
        expect(config.user_identifier.call(double(:User, id: 123))).to eq(123)
        expect(config.entity_table_checks_enabled).to eq(false)
        expect(config.rack_page_cached.call({})).to eq(false)
        expect(config.excluded_paths).to eq([])
        expect(config.excluded_models_proc.call('User')).to eq(false)
        expect(config.database_events_enabled).to eq(true)
        expect(config.airbyte_enabled).to eq(false)
      end
    end

    context 'when azure_federated_auth is true' do
      before do
        # Stub all expected ENV.fetch calls used by .configure
        allow(ENV).to receive(:fetch).with('BIGQUERY_TABLE_NAME', nil).and_return('my_table')
        allow(ENV).to receive(:fetch).with('BIGQUERY_PROJECT_ID', nil).and_return('my_project')
        allow(ENV).to receive(:fetch).with('BIGQUERY_DATASET', nil).and_return('my_dataset')
        allow(ENV).to receive(:fetch).with('BIGQUERY_API_JSON_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('BIGQUERY_MAINTENANCE_WINDOW', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('RAILS_ENV', 'development').and_return('test')

        # Azure-related ENV values
        allow(ENV).to receive(:fetch).with('AZURE_CLIENT_ID', nil).and_return('client-123')
        allow(ENV).to receive(:fetch).with('AZURE_FEDERATED_TOKEN_FILE', nil).and_return('/token/path')
        allow(ENV).to receive(:fetch).with('GOOGLE_CLOUD_CREDENTIALS', '{}').and_return('{"key":"val"}')

        config.azure_federated_auth = true
        described_class.configure(config)
      end

      it 'sets azure and gcp credentials and scopes' do
        expect(config.azure_client_id).to eq('client-123')
        expect(config.azure_token_path).to eq('/token/path')
        expect(config.google_cloud_credentials).to eq(key: 'val')
        expect(config.azure_scope).to eq(DfE::Analytics::AzureFederatedAuth::DEFAULT_AZURE_SCOPE)
        expect(config.gcp_scope).to eq(DfE::Analytics::AzureFederatedAuth::DEFAULT_GCP_SCOPE)
      end
    end

    context 'when airbyte_stream_config_path is set' do
      before do
        config.airbyte_stream_config_path = 'config/airbyte.json'
        described_class.configure(config)
      end

      it 'resolves the full path from Rails.root' do
        expect(config.airbyte_stream_config_path).to eq(Rails.root.join('config/airbyte.json').to_s)
      end
    end
  end
end
