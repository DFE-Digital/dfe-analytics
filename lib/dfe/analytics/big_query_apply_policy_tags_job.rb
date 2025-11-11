# frozen_string_literal: true

module DfE
  module Analytics
    # Applies BigQuery hidden policy tags to PII fields in the airbyte tables
    class BigQueryApplyPolicyTagsJob < AnalyticsJob
      def self.do(dataset:, tables:, policy_tag:, delay_in_minutes: 0)
        if delay_in_minutes.zero?
          perform_later(dataset, tables, policy_tag)
        else
          time_to_run = Time.zone.now + delay_in_minutes.minutes

          set(wait_until: time_to_run).perform_later(dataset, tables, policy_tag)
        end
      end

      def perform(dataset, tables, policy_tag)
        unless DfE::Analytics.airbyte_enabled?
          Rails.logger.warn('DfE::Analytics::BigQueryApplyPolicyTags.perform called but airbyte is disabled. Please check DfE::Analytics.airbyte_enabled? before applying policy tags in BigQuery')
          return
        end

        DfE::Analytics::BigQueryApi.apply_policy_tags(dataset, tables, policy_tag)
      end
    end
  end
end
