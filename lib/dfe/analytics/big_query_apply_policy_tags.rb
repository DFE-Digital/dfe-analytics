# frozen_string_literal: true

module DfE
  module Analytics
    # Applies BigQuery hidden policy tags to PII fields in the airbyte tables
    class BigQueryApplyPolicyTags < AnalyticsJob
      def self.do(delay_in_minutes: 0)
        if delay_in_minutes.zero?
          perform_later
        else
          time_to_run = Time.zone.now + delay_in_minutes.minutes

          set(wait_until: time_to_run).perform_later
        end
      end

      def perform
        unless DfE::Analytics.airbyte_enabled?
          Rails.logger.warn('DfE::Analytics::BigQueryApplyPolicyTags.perform called but airbyte is disabled. Please check DfE::Analytics.airbyte_enabled? before applying policy tags in BigQuery')
          return
        end

        DfE::Analytics::BigQueryApi.apply_policy_tags(
          DfE::Analytics.hidden_pii,
          DfE::Analytics.config.bigquery_hidden_policy_tag
        )
      end
    end
  end
end
