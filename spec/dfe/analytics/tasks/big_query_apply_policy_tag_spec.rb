require 'rake'

require_relative '../../../../lib/dfe/analytics/services/apply_airbyte_final_tables_policy_tags'
require_relative '../../../../lib/dfe/analytics/services/apply_airbyte_internal_tables_policy_tags'

RSpec.describe 'dfe:analytics:big_query_apply_policy_tags' do
  before :all do
    Rake.application.rake_require('big_query_apply_policy_tags', [File.expand_path('../../../../lib/dfe/analytics/tasks', __dir__)])
    Rake::Task.define_task(:environment)
    Rake.application.load_rakefile
  end

  let(:task_name) { 'dfe:analytics:big_query_apply_policy_tags' }
  let(:task) { Rake::Task[task_name] }

  before do
    allow(DfE::Analytics::Services::ApplyAirbyteFinalTablesPolicyTags).to receive(:call)
    allow(DfE::Analytics::Services::ApplyAirbyteInternalTablesPolicyTags).to receive(:call)
    task.reenable # allow re-invocation in the same test run
  end

  context 'when delay_in_minutes is passed' do
    it 'calls both services with the provided delay' do
      task.invoke('15')

      expect(DfE::Analytics::Services::ApplyAirbyteFinalTablesPolicyTags).to have_received(:call).with(delay_in_minutes: 15)
      expect(DfE::Analytics::Services::ApplyAirbyteInternalTablesPolicyTags).to have_received(:call).with(delay_in_minutes: 15)
    end
  end

  context 'when delay_in_minutes is not passed' do
    it 'calls both services with a default delay of 0' do
      task.invoke

      expect(DfE::Analytics::Services::ApplyAirbyteFinalTablesPolicyTags).to have_received(:call).with(delay_in_minutes: 0)
      expect(DfE::Analytics::Services::ApplyAirbyteInternalTablesPolicyTags).to have_received(:call).with(delay_in_minutes: 0)
    end
  end
end
