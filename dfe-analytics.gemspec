# frozen_string_literal: true

require_relative 'lib/dfe/analytics/version'

Gem::Specification.new do |spec|
  spec.name          = 'dfe-analytics'
  spec.version       = DfE::Analytics::VERSION
  spec.authors       = ['Duncan Brown']
  spec.email         = ['duncan.brown@digital.education.gov.uk']

  spec.summary       = 'Event pump for DfE Rails applications'
  spec.homepage      = 'https://teacher-services-tech-docs.london.cloudapps.digital/#teacher-services-technical-documentation'
  spec.license       = 'MIT'
  # should we set a higher version here?
  spec.required_ruby_version = Gem::Requirement.new('>= 3.0.0')

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/DFE-Digital/dfe-analytics'
  spec.metadata['changelog_uri'] = 'https://github.com/DFE-Digital/dfe-analytics/blob/main/CHANGELOG.md'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'google-cloud-bigquery', '~> 1.38'
  spec.add_dependency 'httparty', '~> 0.21'
  spec.add_dependency 'multi_xml', '~> 0.6.0'
  spec.add_dependency 'request_store_rails', '~> 2'

  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'debug', '>= 1.0.0'
  spec.add_development_dependency 'gem-release', '~> 2.2'
  spec.add_development_dependency 'github_changelog_generator', '~> 1.16'
  spec.add_development_dependency 'json-schema', '~> 2.8'
  spec.add_development_dependency 'pry', '~> 0'
  spec.add_development_dependency 'rails', '>= 7'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'rubocop', '~> 1.54'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.22'
  spec.add_development_dependency 'solargraph'
  spec.add_development_dependency 'sqlite3', '~> 2.2'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'webmock', '~> 3.14'
  spec.add_development_dependency 'with_model'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
