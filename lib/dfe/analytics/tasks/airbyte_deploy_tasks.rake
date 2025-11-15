namespace :dfe do
  namespace :analytics do
    desc 'Performs Airbyte deployment tasks: refresh connection, run sync, and apply BigQuery policy tags'
    task airbyte_deploy_tasks: :environment do
      DfE::Analytics::AirbyteDeployJob.perform_later

      puts 'Starting Airbyte deployment tasks...'
    end
  end
end
