# frozen_string_literal: true
#
require "rails/generators"
require_relative '../../../../lib/generators/dfe/analytics/install_generator'

RSpec.describe DfE::Analytics::InstallGenerator do
  subject(:generator) { described_class.new([], {}, {}) }

  let(:airbyte_stream_config_path) { 'config/airbyte_stream_config.json' }

  let(:config_double) do
    instance_double(
      'DfE::Analytics.config',
      airbyte_stream_config_path: airbyte_stream_config_path,
      members: %i[option_one option_two]
    )
  end

  before do
    allow(DfE::Analytics).to receive(:config).and_return(config_double)
  end

  describe '#install' do
    let(:generated_stream_config) { "{\n  \"configurations\": {}\n}" }
    let(:config_options_output) do
      [
        "# First option description\n#\n# config.option_one = 'default_one'\n",
        "# Second option description\n#\n# config.option_two = 'default_two'\n"
      ]
    end

    before do
      allow(generator).to receive(:config_options).and_return(config_options_output)
      allow(DfE::Analytics::AirbyteStreamConfig).to receive(:generate_pretty_json_for)
        .with(table1: %w[id field1 field2])
        .and_return(generated_stream_config)

      allow(generator).to receive(:create_file)
      allow(generator).to receive(:indent).and_call_original
    end

    it 'creates the initializer file' do
      generator.install

      expect(generator).to have_received(:create_file).with(
        'config/initializers/dfe_analytics.rb',
        a_string_including('DfE::Analytics.configure do |config|')
      )
    end

    it 'creates the analytics yaml files' do
      generator.install

      expect(generator).to have_received(:create_file).with(
        'config/analytics.yml',
        { 'shared' => {} }.to_yaml
      )
      expect(generator).to have_received(:create_file).with(
        'config/analytics_hidden_pii.yml',
        { 'shared' => {} }.to_yaml
      )
      expect(generator).to have_received(:create_file).with(
        'config/analytics_blocklist.yml',
        { 'shared' => {} }.to_yaml
      )
    end
    it 'creates the airbyte stream config file' do
      generator.install

      expect(generator).to have_received(:create_file).with(
        airbyte_stream_config_path,
        generated_stream_config
      )
    end

    it 'uses the generated config options in the initializer' do
      generator.install

      expect(generator).to have_received(:create_file).with(
        'config/initializers/dfe_analytics.rb',
        a_string_including('# First option description')
      )
      expect(generator).to have_received(:create_file).with(
        'config/initializers/dfe_analytics.rb',
        a_string_including("# config.option_one = 'default_one'")
      )
      expect(generator).to have_received(:create_file).with(
        'config/initializers/dfe_analytics.rb',
        a_string_including('# Second option description')
      )
      expect(generator).to have_received(:create_file).with(
        'config/initializers/dfe_analytics.rb',
        a_string_including("# config.option_two = 'default_two'")
      )
    end
  end

  describe '#config_options' do
    before do
      allow(I18n).to receive(:t).with('dfe.analytics.config.option_one.description')
        .and_return('First option description')
      allow(I18n).to receive(:t).with('dfe.analytics.config.option_one.default')
        .and_return("'default_one'")

      allow(I18n).to receive(:t).with('dfe.analytics.config.option_two.description')
        .and_return("Second option description\nWith another line")
      allow(I18n).to receive(:t).with('dfe.analytics.config.option_two.default')
        .and_return("'default_two'")
    end

    it 'builds commented config entries for each config member' do
      result = generator.send(:config_options)

      expect(result).to eq(
        [
          <<~TEXT,
            # First option description
            #
            # config.option_one = 'default_one'

          TEXT
          <<~TEXT
            # Second option description
            # With another line
            #
            # config.option_two = 'default_two'

          TEXT
        ]
      )
    end
  end
end
