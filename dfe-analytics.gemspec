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
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/DFE-Digital/dfe-analytics'
  spec.metadata['changelog_uri'] = 'https://github.com/DFE-Digital/dfe-analytics/blob/main/CHANGELOG.md'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'google-cloud-bigquery', '~> 1.38'
  spec.add_dependency 'i18n'
  spec.add_dependency 'rails', '>= 6'
  spec.add_dependency 'request_store_rails', '~> 2'

  spec.add_development_dependency 'json-schema', '~> 2.8'
  spec.add_development_dependency 'rspec-rails', '~> 5.0'
  spec.add_development_dependency 'rubocop', '~> 1.26'
  spec.add_development_dependency 'rubocop-rspec', '~> 2'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'webmock', '~> 3.14'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
