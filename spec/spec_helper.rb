# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'
require_relative '../spec/dummy/config/environment'
require 'debug'
require 'rspec/rails'
require 'webmock/rspec'
require 'json-schema'
require 'with_model'
require 'dfe/analytics/testing'
require 'dfe/analytics/testing/helpers'

require_relative '../spec/support/json_schema_validator'

if ::Rails::VERSION::MAJOR >= 7
  require 'active_support/testing/tagged_logging'

  RSpec::Core::ExampleGroup.module_eval do
    include ActiveSupport::Testing::TaggedLogging

    def name; end
  end
end

ActiveRecord::Migrator.migrations_paths = [File.expand_path('../spec/dummy/db/migrate', __dir__)]

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.use_transactional_fixtures = true

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.extend WithModel

  include DfE::Analytics::Testing::Helpers

  config.before do
    DfE::Analytics.instance_variable_set(:@entity_model_mapping, nil)
  end

  config.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end
end
