require 'rake'

RSpec.describe 'dfe:analytics:big_query_apply_policy_tags' do
  before :all do
    Rake.application.rake_require('big_query_apply_policy_tags', [File.expand_path('../../../../lib/dfe/analytics/tasks', __dir__)])
    Rake::Task.define_task(:environment)
    Rake.application.load_rakefile
  end

  let(:task_name) { 'dfe:analytics:big_query_apply_policy_tags' }
  let(:task) { Rake::Task[task_name] }

  before do
    allow(DfE::Analytics::BigQueryApplyPolicyTags).to receive(:do)
    task.reenable # allow re-invocation in the same test run
  end

  it 'calls .do with delay_in_minutes when passed' do
    task.invoke('15')
    expect(DfE::Analytics::BigQueryApplyPolicyTags).to have_received(:do).with(delay_in_minutes: 15)
  end

  it 'defaults delay_in_minutes to 0 when no argument is given' do
    task.invoke
    expect(DfE::Analytics::BigQueryApplyPolicyTags).to have_received(:do).with(delay_in_minutes: 0)
  end
end
