# frozen_string_literal: true

require 'active_support/values/time_zone'

module DfE
  module Analytics
    # To ensure BigQuery is in sync with the database
    class EntityTableCheckJob < AnalyticsJob
      TIME_ZONE = 'London'

      def perform
        return unless DfE::Analytics.entity_table_checks_enabled?
        return unless supported_adapter_and_environment?

        DfE::Analytics.entities_for_analytics.each do |entity|
          entity_table_check_event = build_event_for(entity)
          DfE::Analytics::SendEvents.perform_later([entity_table_check_event]) if entity_table_check_event.present?
        end
      end

      def build_event_for(entity)
        unless DfE::Analytics.models_for_entity(entity).any?
          Rails.logger.info("DfE::Analytics NOT Processing entity: #{entity} - No associated models")
          return
        end

        DfE::Analytics::Event.new
          .with_type('entity_table_check')
          .with_entity_table_name(entity)
          .with_data(entity_table_check_data(entity))
          .as_json
      end

      def adapter_name
        @adapter_name ||= ActiveRecord::Base.connection.adapter_name.downcase
      end

      def entity_table_check_data(entity)
        checksum_calculated_at = fetch_current_timestamp_in_time_zone

        row_count, checksum = fetch_checksum_data(entity, checksum_calculated_at)
        Rails.logger.info("DfE::Analytics Processing entity: #{entity}: Row count: #{row_count}")
        {
          row_count: row_count,
          checksum: checksum,
          checksum_calculated_at: checksum_calculated_at
        }
      end

      def supported_adapter_and_environment?
        return true if adapter_name == 'postgresql' || !Rails.env.production?

        Rails.logger.info('DfE::Analytics: Entity checksum: Only Postgres databases supported on PRODUCTION')

        false
      end

      def fetch_current_timestamp_in_time_zone
        result = ActiveRecord::Base.connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp')
        result.first['current_timestamp'].in_time_zone(TIME_ZONE).iso8601(6)
      end

      def fetch_checksum_data(entity, checksum_calculated_at)
        return [0, ''] unless ActiveRecord::Base.connection.column_exists?(entity, :id)

        table_name_sanitized = ActiveRecord::Base.connection.quote_table_name(entity)
        checksum_calculated_at_sanitized = ActiveRecord::Base.connection.quote(checksum_calculated_at)
        order_column = determine_order_column(entity)

        if adapter_name == 'postgresql'
          fetch_postgresql_checksum_data(table_name_sanitized, checksum_calculated_at_sanitized, order_column)
        else
          fetch_generic_checksum_data(table_name_sanitized, checksum_calculated_at_sanitized, order_column)
        end
      end

      def determine_order_column(entity)
        if ActiveRecord::Base.connection.column_exists?(entity, :updated_at)
          'UPDATED_AT'
        elsif ActiveRecord::Base.connection.column_exists?(entity, :created_at)
          'CREATED_AT'
        else
          'ID'
        end
      end

      def fetch_postgresql_checksum_data(table_name_sanitized, checksum_calculated_at_sanitized, order_column)
        checksum_sql_query = <<-SQL
          SELECT COUNT(*) as row_count,
            MD5(COALESCE(STRING_AGG(CHECKSUM_TABLE.ID, '' ORDER BY CHECKSUM_TABLE.#{order_column} ASC), '')) as checksum
          FROM (
            SELECT #{table_name_sanitized}.id::TEXT as ID,
                   #{table_name_sanitized}.#{order_column} as #{order_column}
            FROM #{table_name_sanitized}
            WHERE #{table_name_sanitized}.#{order_column} < #{checksum_calculated_at_sanitized}
          ) CHECKSUM_TABLE
        SQL

        result = ActiveRecord::Base.connection.execute(checksum_sql_query).first
        [result['row_count'].to_i, result['checksum']]
      end

      def fetch_generic_checksum_data(table_name_sanitized, checksum_calculated_at_sanitized, order_column)
        checksum_sql_query = <<-SQL
          SELECT #{table_name_sanitized}.ID
          FROM #{table_name_sanitized}
          WHERE #{table_name_sanitized}.#{order_column} < #{checksum_calculated_at_sanitized}
          ORDER BY #{table_name_sanitized}.#{order_column} ASC
        SQL

        table_ids = ActiveRecord::Base.connection.execute(checksum_sql_query).pluck('id')
        [table_ids.count, Digest::MD5.hexdigest(table_ids.join)]
      end
    end
  end
end
