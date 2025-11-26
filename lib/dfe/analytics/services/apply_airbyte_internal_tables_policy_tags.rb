# frozen_string_literal: true

module DfE
  module Analytics
    module Services
      # Apply hidden policy tags to the internal airbyte table columns containing any data
      class ApplyAirbyteInternalTablesPolicyTags
        include ServicePattern

        AIRBYTE_INTERNAL_TABLE_DATA_COLUMN = '_airbyte_data'

        def initialize(delay_in_minutes: 0)
          @delay_in_minutes = delay_in_minutes
        end

        def call
          DfE::Analytics::Jobs::BigQueryApplyPolicyTagsJob.do(
            delay_in_minutes: @delay_in_minutes,
            dataset: DfE::Analytics.config.airbyte_internal_dataset,
            tables: internal_airbyte_tables,
            policy_tag: DfE::Analytics.config.bigquery_hidden_policy_tag
          )
        end

        private

        def internal_airbyte_tables
          DfE::Analytics.allowlist.keys.each_with_object({}) do |table, mem|
            airbyte_internal_table_name = "#{DfE::Analytics.config.airbyte_internal_dataset}_raw__stream_#{table}"

            mem[airbyte_internal_table_name] = AIRBYTE_INTERNAL_TABLE_DATA_COLUMN
          end
        end
      end
    end
  end
end
