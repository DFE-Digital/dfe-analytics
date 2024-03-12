require_relative '../shared/service_pattern'
require_relative '../shared/checksum_query_components'

module DfE
  module Analytics
    module Services
      # Calculates a checksum and row count for a specified entity
      # and order column in a PostgreSQL database
      class PostgresChecksumCalculator
        include ServicePattern
        include ChecksumQueryComponents

        WHERE_CLAUSE_ORDER_COLUMNS = %w[CREATED_AT UPDATED_AT].freeze

        def initialize(entity, order_column, checksum_calculated_at)
          @entity = entity
          @order_column = order_column
          @checksum_calculated_at = checksum_calculated_at
          @connection = ActiveRecord::Base.connection
        end

        def call
          calculate_checksum
        end

        private

        attr_reader :entity, :order_column, :checksum_calculated_at, :connection

        def calculate_checksum
          table_name_sanitized = connection.quote_table_name(entity)
          checksum_calculated_at_sanitized = connection.quote(checksum_calculated_at)
          where_clause = build_where_clause(order_column, table_name_sanitized, checksum_calculated_at_sanitized)
          select_clause, order_by_clause = build_select_and_order_clause(order_column, table_name_sanitized)

          checksum_sql_query = <<-SQL
          SELECT COUNT(*) as row_count,
            MD5(COALESCE(STRING_AGG(CHECKSUM_TABLE.ID, '' ORDER BY #{order_by_clause}), '')) as checksum
          FROM (
            SELECT #{table_name_sanitized}.id::TEXT as ID,
            #{select_clause}
            FROM #{table_name_sanitized}
            #{where_clause}
          ) AS CHECKSUM_TABLE
          SQL

          result = connection.execute(checksum_sql_query).first
          [result['row_count'].to_i, result['checksum']]
        end
      end
    end
  end
end
