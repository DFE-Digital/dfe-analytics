RSpec.describe 'DfE::Analytics fields' do
  specify 'all fields in the database are covered by the blocklist or allowlist' do
    unlisted_fields = described_class.unlisted_fields

    failure_message = <<~HEREDOC
      New database field detected! You need to decide whether or not to send it
      to BigQuery. To send, add it to config/analytics.yml. To ignore, run:

      bundle exec rails bigquery:regenerate_blocklist

      New fields: #{unlisted_fields.inspect}
    HEREDOC

    expect(unlisted_fields).to be_empty, failure_message
  end

  specify 'the allowlist deals only with fields in the database' do
    surplus_fields = described_class.surplus_fields

    failure_message = <<~HEREDOC
      Database field removed! Please remove it from analytics.yml and then run

      bundle exec rails bigquery:regenerate_blocklist

      Removed fields: #{surplus_fields.inspect}
    HEREDOC

    expect(surplus_fields).to be_empty, failure_message
  end
end
