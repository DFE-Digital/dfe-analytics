# frozen_string_literal: true

RSpec.describe DfE::Analytics do
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

  describe '#models_for_analytics' do
    before do
      allow(DfE::Analytics).to receive(:allowlist).and_return({
        candidates: %i[id],
        institutions: %i[id], # table name for the School model, which doesn’t follow convention
      })
    end

    it 'returns the Rails models in the allowlist' do
      expect(DfE::Analytics.models_for_analytics).to eq ['Candidate', 'School']
    end
  end
end
