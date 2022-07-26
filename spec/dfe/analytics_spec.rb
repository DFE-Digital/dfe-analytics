# frozen_string_literal: true

RSpec.describe DfE::Analytics do
  with_model :Candidate do
    table
  end

  it 'has a version number' do
    expect(DfE::Analytics::VERSION).not_to be nil
  end

  it 'has documentation entries for all the config options' do
    config_options = DfE::Analytics.config.members

    config_options.each do |option|
      expect(I18n.t("dfe.analytics.config.#{option}.description")).not_to match(/translation missing/)
      expect(I18n.t("dfe.analytics.config.#{option}.default")).not_to match(/translation missing/)
    end
  end

  it 'raises a configuration error on missing config values' do
    with_analytics_config(bigquery_project_id: nil) do
      DfE::Analytics::Testing.webmock! do
        expect { DfE::Analytics.events_client }.to raise_error(DfE::Analytics::ConfigurationError)
      end
    end
  end

  describe '#entities_for_analytics' do
    before do
      allow(DfE::Analytics).to receive(:allowlist).and_return({
        Candidate.table_name.to_sym => %i[id]
      })
    end

    it 'returns the entities in the allowlist' do
      expect(DfE::Analytics.entities_for_analytics).to eq [Candidate.table_name.to_sym]
    end
  end
end
