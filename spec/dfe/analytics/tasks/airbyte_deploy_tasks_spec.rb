# frozen_string_literal: true

require 'rake'

RSpec.describe 'dfe:analytics:airbyte_deploy_tasks' do
  before :all do
    Rake.application.rake_require(
      'airbyte_deploy_tasks',
      [File.expand_path('../../../../lib/dfe/analytics/tasks', __dir__)]
    )
    Rake::Task.define_task(:environment)
    Rake.application.load_rakefile
  end

  let(:task_name) { 'dfe:analytics:airbyte_deploy_tasks' }
  let(:task) { Rake::Task[task_name] }

  before do
    allow(DfE::Analytics::AirbyteDeployJob).to receive(:perform_later)
    task.reenable # so we can invoke multiple times
  end

  it 'enqueues the AirbyteDeployJob' do
    expect do
      task.invoke
    end.to output(/Starting Airbyte deployment tasks.../).to_stdout

    expect(DfE::Analytics::AirbyteDeployJob).to have_received(:perform_later)
  end
end
