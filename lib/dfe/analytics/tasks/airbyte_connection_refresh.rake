namespace :dfe do
  namespace :analytics do
    desc 'Refresh the airbyte connection and schema'
    task :airbyte_connection_refresh do
      Services::Airbyte::ConnectionRefresh.call

      puts 'Airbyte connection and schema refreshed OK'
    end
  end
end
