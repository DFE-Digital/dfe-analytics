# frozen_string_literal: true

require 'active_support/values/time_zone'

module DfE
  module Analytics
    # To ensure BigQuery is in sync with the database
    class EntityTableCheckJob < AnalyticsJob
      def perform
        return unless DfE::Analytics.entity_table_checks_enabled?

        entity_tag = Time.now.strftime('%Y%m%d%H%M%S')
        DfE::Analytics.entities_for_analytics.each do |entity_name|
          DfE::Analytics::Services::EntityTableChecks.call(entity_name: entity_name, entity_type: 'entity_table_check', entity_tag: entity_tag)
        end
      end
    end
  end
end
