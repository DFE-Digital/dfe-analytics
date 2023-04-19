# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'
ENV['SUPPRESS_DFE_ANALYTICS_INIT'] = 'true'
ENV['RAILS_SERVE_STATIC_FILES'] = 'true'

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

  config.around do |example|
    ActiveRecord::Base.connection.migration_context.migrate
    example.run
  end

  config.define_derived_metadata do |metadata|
    metadata[:skip_analytics_init] = true unless metadata[:skip_analytics_init] == false
  end

  config.around skip_analytics_init: false do |example|
    DfE::Analytics.initialize!
    example.run
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.extend WithModel

  include DfE::Analytics::Testing::Helpers

  config.before do
    DfE::Analytics.instance_variable_set(:@entity_model_mapping, nil)
    DfE::Analytics.instance_variable_set(:@events_client, nil)
  end

  config.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end
end
