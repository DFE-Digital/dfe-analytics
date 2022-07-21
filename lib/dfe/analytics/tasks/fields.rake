namespace :dfe do
  namespace :analytics do
    desc 'Generate a new field blocklist containing all the fields not listed for sending to Bigquery'
    task check: :environment do
      surplus_fields = DfE::Analytics::Fields.surplus_fields
      unlisted_fields = DfE::Analytics::Fields.unlisted_fields
      conflicting_fields = DfE::Analytics::Fields.conflicting_fields

      surplus_fields_failure_message = <<~HEREDOC
        Database field removed! Please remove it from analytics.yml and then run

        bundle exec rails dfe:analytics:regenerate_blocklist

        Removed fields:

        #{surplus_fields.to_yaml}
      HEREDOC

      unlisted_fields_failure_message = <<~HEREDOC
        New database field detected! You need to decide whether or not to send it
        to BigQuery. To send, add it to config/analytics.yml. To ignore, run:

        bundle exec rails dfe:analytics:regenerate_blocklist

        New fields:

        #{unlisted_fields.to_yaml}
      HEREDOC

      conflicting_fields_failure_message = <<~HEREDOC
        Conflict detected between analytics.yml and analytics_blocklist.yml!

        The following fields exist in both files. To remove from the blocklist, run:

        bundle exec rails dfe:analytics:regenerate_blocklist

        Conflicting fields:

        #{conflicting_fields.to_yaml}
      HEREDOC

      puts unlisted_fields_failure_message if unlisted_fields.any?

      puts surplus_fields_failure_message if surplus_fields.any?

      puts conflicting_fields_failure_message if conflicting_fields.any?

      raise if surplus_fields.any? || unlisted_fields.any? || conflicting_fields.any?
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
