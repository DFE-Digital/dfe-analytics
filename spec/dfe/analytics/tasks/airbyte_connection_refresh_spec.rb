require 'rake'

RSpec.describe 'dfe:analytics:airbyte_connection_refresh Rake task' do
  before do
    Rake.application.rake_require('airbyte_connection_refresh', [File.expand_path('../../../../lib/dfe/analytics/tasks', __dir__)])
    Rake::Task.define_task(:environment)
    Rake.application.load_rakefile

    allow(Services::Airbyte::ConnectionRefresh).to receive(:call)
  end

  it 'calls the ConnectionRefresh service and prints success message' do
    expect { Rake::Task['dfe:analytics:airbyte_connection_refresh'].invoke }
      .to output(/Airbyte connection and schema refreshed OK/).to_stdout

    expect(Services::Airbyte::ConnectionRefresh).to have_received(:call)
  end
end
