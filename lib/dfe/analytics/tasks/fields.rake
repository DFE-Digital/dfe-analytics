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
  end
end
