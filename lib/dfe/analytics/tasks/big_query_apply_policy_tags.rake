namespace :dfe do
  namespace :analytics do
    desc 'Apply BigQuery policy tags to final and internal airbyte tables. Optionally pass delay_in_minutes (default is 0)'
    task :big_query_apply_policy_tags, [:delay_in_minutes] => :environment do |_, args|
      delay = args[:delay_in_minutes].to_i

      puts "Calling DfE::Analytics::Services::ApplyAirbyteFinalTablesPolicyTags.call(delay_in_minutes: #{delay})"
      DfE::Analytics::Services::ApplyAirbyteFinalTablesPolicyTags.call(delay_in_minutes: delay)

      puts "Calling DfE::Analytics::Services::ApplyAirbyteInternalTablesPolicyTags.call(delay_in_minutes: #{delay})"
      DfE::Analytics::Services::ApplyAirbyteInternalTablesPolicyTags.call(delay_in_minutes: delay)
    end
  end
end
