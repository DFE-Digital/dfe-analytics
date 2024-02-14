require_relative '../shared/service_pattern'

module DfE
  module Analytics
    module Services
      # Calculates a checksum and row count for a specified entity
      # and order column in a PostgreSQL database
      class PostgresChecksumCalculator
        include ServicePattern

        ALLOWED_ORDER_COLUMNS = %w[CREATED_AT UPDATED_AT].freeze

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
          # where_clause = build_where_clause(order_column, table_name_sanitized, checksum_calculated_at_sanitized)

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

          result = connection.execute(checksum_sql_query).first
          [result['row_count'].to_i, result['checksum']]
        end

        def build_where_clause(order_column, table_name_sanitized, checksum_calculated_at_sanitized)
          return '' unless ALLOWED_ORDER_COLUMNS.include?(order_column)

          "WHERE #{table_name_sanitized}.#{order_column} < #{checksum_calculated_at_sanitized}"
        end
      end
    end
  end
end
