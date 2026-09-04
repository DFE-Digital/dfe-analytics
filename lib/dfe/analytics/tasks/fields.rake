namespace :dfe do
  namespace :analytics do
    desc 'Identify issues with the analytics fields listings'
    task check: :environment do
      DfE::Analytics::Fields.check!
    end

    desc 'Generate a new field blocklist containing all the fields not listed for sending to Bigquery'
    task regenerate_blocklist: :environment do
      File.write(
        Rails.root.join('config/analytics_blocklist.yml'),
        { shared: DfE::Analytics::Fields.generate_blocklist }.to_yaml
      )
    end

    desc 'Generate a debug airbyte stream config listing all fields to be send to Bigquery from analytics.yml. Generates debug_airbyte_config.json.'
    task airbyte_stream_config_for_debug: :environment do
      File.write(
        'debug_airbyte_config.json',
        DfE::Analytics::AirbyteStreamConfig.generate_pretty_json_for(DfE::Analytics.allowlist)
      )
    end
  end
end
