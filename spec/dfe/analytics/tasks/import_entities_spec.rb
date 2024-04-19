require 'rake'

RSpec.describe 'dfe:analytics:import_entity Rake task' do
  with_model :Candidate do
    table do |t|
      t.string :email_address
    end
  end

  let(:rake) { Rake::Application.new }
  let(:task_name) { 'dfe:analytics:import_entity' }
  let(:entity_name) { 'Candidate' }
  let(:entity_tag) { Time.now.strftime('%Y%m%d%H%M%S') }

  before do
    Rake.application.rake_require('import_entities', [File.expand_path('../../../../lib/dfe/analytics/tasks', __dir__)])
    Rake::Task.define_task(:environment)

    allow(DfE::Analytics).to receive(:models_for_entity).and_return([Candidate])
    allow(DfE::Analytics::LoadEntities).to receive_message_chain(:new, :run)
    allow(DfE::Analytics::Services::EntityTableChecks).to receive(:call)
    Candidate.create(email_address: 'known@address.com')
  end

  it 'invokes LoadEntities and EntityTableChecks with correct parameters' do
    expect(DfE::Analytics::LoadEntities).to receive(:new).with(entity_name: entity_name).and_call_original
    expect(DfE::Analytics::Services::EntityTableChecks).to receive(:call).with(
      entity_name: entity_name,
      entity_type: 'import_entity_table_check',
      entity_tag: entity_tag
    )

    Rake::Task[task_name].reenable
    Rake::Task[task_name].invoke(entity_name)
  end
end
