namespace :dfe do
  namespace :analytics do
    desc 'Apply BigQuery policy tags. Optionally pass delay_in_minutes (default is 0)'
    task :big_query_apply_policy_tags, [:delay_in_minutes] => :environment do |_, args|
      delay = args[:delay_in_minutes].to_i || 0

      puts "Calling DfE::Analytics::BigQueryApplyPolicyTags.do(delay_in_minutes: #{delay})"
      DfE::Analytics::BigQueryApplyPolicyTags.do(delay_in_minutes: delay)
    end
  end
end
