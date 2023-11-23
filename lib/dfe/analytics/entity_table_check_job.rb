# frozen_string_literal: true

require 'active_support/values/time_zone'

module DfE
  module Analytics
    # To ensure BigQuery is in sync with the database
    class EntityTableCheckJob < AnalyticsJob
      TIME_ZONE = 'London'

      def perform
        return unless DfE::Analytics.entity_table_checks_enabled?

        DfE::Analytics.entities_for_analytics.each do |entity_name|
          entity_table_check_event = build_event_for(entity_name)
          DfE::Analytics::SendEvents.perform_later([entity_table_check_event])
        end
      end

      def build_event_for(entity_name)
        model = DfE::Analytics.models_for_entity(entity_name).last
        Rails.logger.info("Processing data for #{model.table_name} with row count #{model.count}") 

        DfE::Analytics::Event.new
          .with_type('entity_table_check')
          .with_entity_table_name(model.table_name)
          .with_data(entity_table_check_data(model))
          .as_json
      end

      def entity_table_check_data(model)
        adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
        return unless supported_adapter_and_environment?(adapter_name)

        checksum_calculated_at = fetch_current_timestamp_in_time_zone

        row_count, checksum = fetch_checksum_data(model, adapter_name, checksum_calculated_at)
        {
          row_count: row_count,
          checksum: checksum,
          checksum_calculated_at: checksum_calculated_at
        }
      end

      def supported_adapter_and_environment?(adapter_name)
        if adapter_name != 'postgresql' && Rails.env.production?
          Rails.logger.info('DfE::Analytics: Entity checksum: Only Postgres databases supported on PRODUCTION')
          return false
        end
        true
      end

      def fetch_current_timestamp_in_time_zone
        result = ActiveRecord::Base.connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp')
        result.first['current_timestamp'].in_time_zone(TIME_ZONE).iso8601(6)
      end

      def fetch_checksum_data(model, adapter_name, checksum_calculated_at)
        if adapter_name == 'postgresql'
          fetch_postgresql_checksum_data(model, checksum_calculated_at)
        else
          fetch_generic_checksum_data(model, checksum_calculated_at)
        end
      end

      def fetch_postgresql_checksum_data(model, checksum_calculated_at)
        sanitized_table_name = ActiveRecord::Base.connection.quote_table_name(model.table_name)
        checksum_calculated_at_sanitized = ActiveRecord::Base.connection.quote(checksum_calculated_at)
        checksum_sql_query = <<-SQL
          SELECT COUNT(*) as row_count,
            MD5(COALESCE(STRING_AGG(CHECKSUM_TABLE.ID, '' ORDER BY CHECKSUM_TABLE.UPDATED_AT ASC), '')) as checksum
          FROM (
            SELECT #{sanitized_table_name}.id::TEXT as ID,
                   #{sanitized_table_name}.updated_at as UPDATED_AT
            FROM #{sanitized_table_name}
            WHERE #{sanitized_table_name}.updated_at < #{checksum_calculated_at_sanitized}
          ) CHECKSUM_TABLE
        SQL

        result = ActiveRecord::Base.connection.execute(checksum_sql_query).first
        [result['row_count'].to_i, result['checksum']]
      end

      def fetch_generic_checksum_data(model, checksum_calculated_at)
        table_ids =
          model
          .where('updated_at < ?', checksum_calculated_at)
          .order(updated_at: :asc)
          .pluck(:id)
        [table_ids.count, Digest::MD5.hexdigest(table_ids.join)]
      end
    end
  end
end
