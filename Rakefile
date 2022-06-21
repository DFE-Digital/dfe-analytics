# frozen_string_literal: true

require 'bundler/setup'

require 'bundler/gem_tasks'

desc 'Prepare a new version for release, version can be major, minor, patch or x.y.z (as per gem-release gem)'
task :prepare_release, %i[version] do |_, args|
  bump_version = args.fetch(:version)

  current_branch = `git branch --show-current`.chomp
  raise 'could not get current branch' if current_branch.empty?

  sh 'git', 'checkout', '-b', 'new-release' if current_branch == 'main'

  sh 'gem', 'bump', '-v', bump_version, '--no-commit'

  version = `ruby -rrubygems -e 'puts Gem::Specification::load("dfe-analytics.gemspec").version'`.chomp
  raise 'could not retrieve version' if version.empty?

  sh 'github_changelog_generator', '--no-verbose', '--future-release', version

  sh 'git', 'commit', '-a', '-m', version

  sh 'git', 'tag', version
end
