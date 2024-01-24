# frozen_string_literal: true

require 'active_support/values/time_zone'
require_relative 'shared/checksum_logic'

module DfE
  module Analytics
    # To ensure BigQuery is in sync with the database
    class EntityTableCheckJob < AnalyticsJob
      include ChecksumLogic

      def perform
        return unless DfE::Analytics.entity_table_checks_enabled?
        return unless supported_adapter_and_environment?

        DfE::Analytics.entities_for_analytics.each do |entity|
          columns = DfE::Analytics.allowlist[entity]
          next unless id_column_exists_for_entity?(entity)
          next unless order_column_exposed_for_entity?(entity, columns)

          order_column = determine_order_column(entity, columns)

          entity_table_check_event = build_event_for(entity, order_column)
          DfE::Analytics::SendEvents.perform_later([entity_table_check_event]) if entity_table_check_event.present?
        end
      end

      def build_event_for(entity, order_column)
        unless DfE::Analytics.models_for_entity(entity).any?
          Rails.logger.info("DfE::Analytics NOT Processing entity: #{entity} - No associated models")
          return
        end

        DfE::Analytics::Event.new
          .with_type('entity_table_check')
          .with_entity_table_name(entity)
          .with_data(entity_table_check_data(entity, order_column))
          .as_json
      end
    end
  end
end
