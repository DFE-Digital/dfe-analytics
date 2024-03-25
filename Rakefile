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

  version = `bundle exec ruby -e 'puts DfE::Analytics::VERSION'`.chomp
  raise 'could not retrieve version' if version.empty?

  v_version = "v#{version}"

  sh 'github_changelog_generator', '--no-verbose', '--future-release', v_version, '--exclude-labels', 'version-release'

  sh 'git', 'commit', '-a', '-m', v_version

  puts <<~EOMESSAGE
    Release #{v_version} is almost ready! Before you push:

    - Check that the CHANGELOG.md has no empty sections with no changes listed,
      duplicate version numbers (e.g. two v1.5.1 entries) or non-version entries
      (e.g. "push"). There should also only typically be a section added for the
      latest version being cut, and no changes to previous entries.

        git show -- CHANGELOG.md

  EOMESSAGE
end
