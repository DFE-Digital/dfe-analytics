# frozen_string_literal: true

module DfE
  module Analytics
    module Services
      # Apply hidden policy tags to the final airbyte table columns in the hidden pii config
      class ApplyAirbyteFinalTablesPolicyTags
        include ServicePattern

        def initialize(delay_in_minutes: 0)
          @delay_in_minutes = delay_in_minutes
        end

        def call
          DfE::Analytics::Jobs::BigQueryApplyPolicyTagsJob.do(
            delay_in_minutes: @delay_in_minutes,
            dataset: DfE::Analytics.config.bigquery_airbyte_dataset,
            tables: DfE::Analytics.hidden_pii,
            policy_tag: DfE::Analytics.config.bigquery_hidden_policy_tag
          )
        end
      end
    end
  end
end
