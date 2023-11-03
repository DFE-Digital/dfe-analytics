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
          DfE::Analytics.models_for_entity(entity_name).each do |model|
            entity_table_check_event = DfE::Analytics::Event.new
                                                            .with_type('entity_table_check')
                                                            .with_entity_table_name(model.table_name)
                                                            .with_data(entity_table_check_data(model))
                                                            .as_json
            DfE::Analytics::SendEvents.perform_later([entity_table_check_event])
            Rails.logger.info("Processing data for #{model.table_name} with row count #{model.count}")
          end
        end
      end

      def entity_table_check_data(model)
        checksum_calculated_at = Time.now.in_time_zone(TIME_ZONE).iso8601(6)
        adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
        row_count, checksum = fetch_checksum_data(model, checksum_calculated_at, adapter_name)

        {
          row_count: row_count,
          checksum: checksum,
          checksum_calculated_at: checksum_calculated_at
        }
      end

      def fetch_checksum_data(model, checksum_calculated_at, adapter_name)
        if adapter_name == 'postgresql'
          fetch_postgresql_checksum_data(model, checksum_calculated_at)
        else
          fetch_generic_checksum_data(model, checksum_calculated_at)
        end
      end

      def fetch_postgresql_checksum_data(model, checksum_calculated_at)
        checksum_sql_query = <<-SQL
          SELECT COUNT(*) as row_count,
            MD5(STRING_AGG(CHECKSUM_TABLE.ID, '')) as checksum
          FROM (
            SELECT #{model.table_name}.id::TEXT as ID
            FROM #{model.table_name}
            WHERE #{model.table_name}.updated_at < '#{checksum_calculated_at}'
            ORDER BY #{model.table_name}.updated_at ASC
          ) CHECKSUM_TABLE
        SQL

        result = ActiveRecord::Base.connection.execute(checksum_sql_query).first
        [result['row_count'].to_i, result['checksum']]
      end

      def fetch_generic_checksum_data(model, checksum_calculated_at)
        table_ids =
          model
          .where('updated_at < ?', Time.parse(checksum_calculated_at))
          .order(updated_at: :asc)
          .pluck(:id)
        [table_ids.count, Digest::SHA256.hexdigest(table_ids.join)]
      end
    end
  end
end
