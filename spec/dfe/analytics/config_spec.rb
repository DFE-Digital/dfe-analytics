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
        expect(config.ignore_default_scope).to eq(false)
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
        allow(ENV).to receive(:fetch).with('BIGQUERY_AIRBYTE_DATASET', nil).and_return('my_airbyte_dataset')
        allow(ENV).to receive(:fetch).with('BIGQUERY_API_JSON_KEY', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('BIGQUERY_HIDDEN_POLICY_TAG', nil).and_return('my_policy_tag')
        allow(ENV).to receive(:fetch).with('BIGQUERY_MAINTENANCE_WINDOW', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('RAILS_ENV', 'development').and_return('test')
        allow(ENV).to receive(:fetch).with('AIRBYTE_CLIENT_ID', nil).and_return('my_client_id')
        allow(ENV).to receive(:fetch).with('AIRBYTE_CLIENT_SECRET', nil).and_return('my_client_secret')
        allow(ENV).to receive(:fetch).with('AIRBYTE_SERVER_URL', nil).and_return('my_server_url')
        allow(ENV).to receive(:fetch).with('AIRBYTE_WORKSPACE_ID', nil).and_return('my_workspace_id')

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

  describe '.check_missing_config!' do
    let(:config_keys) { %i[foo bar baz] }

    before do
      allow(DfE::Analytics.config).to receive(:foo).and_return('value')
      allow(DfE::Analytics.config).to receive(:bar).and_return(nil)
      allow(DfE::Analytics.config).to receive(:baz).and_return('')
    end

    context 'when all required config values are present' do
      before do
        allow(DfE::Analytics.config).to receive(:bar).and_return('present')
        allow(DfE::Analytics.config).to receive(:baz).and_return('also_present')
      end

      it 'does not raise an error' do
        expect do
          described_class.check_missing_config!(config_keys)
        end.not_to raise_error
      end
    end

    context 'when some config values are missing' do
      it 'raises ConfigurationError with the missing keys' do
        expect do
          described_class.check_missing_config!(config_keys)
        end.to raise_error(DfE::Analytics::Config::ConfigurationError, /missing required config values: bar, baz/)
      end
    end
  end
end
