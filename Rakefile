# frozen_string_literal: true

require 'bundler/setup'

require 'bundler/gem_tasks'

desc 'Prepare a new version for release, version can be major, minor, patch or x.y.z (as per gem-release gem)'
task :prepare_release, %i[version] do |_, args|
  bump_version = args.fetch(:version)

  sh 'gem', 'bump', '-v', bump_version, '--no-commit'

  version = `ruby -rrubygems -e 'puts Gem::Specification::load("dfe-analytics.gemspec").version'`.chomp

  sh 'github_changelog_generator', '--no-verbose', '--future-release', version

end
