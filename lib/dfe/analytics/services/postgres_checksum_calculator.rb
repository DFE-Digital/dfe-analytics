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

        def build_select_and_order_clause(order_column, table_name_sanitized)
          case order_column.downcase
          when 'updated_at'
            select_clause = "#{table_name_sanitized}.updated_at as updated_at_alias, "
            order_by_clause = 'ORDER BY CHECKSUM_TABLE.updated_at_alias ASC, CHECKSUM_TABLE.ID ASC'
          when 'created_at'
            select_clause = "#{table_name_sanitized}.created_at as created_at_alias, "
            order_by_clause = 'ORDER BY CHECKSUM_TABLE.created_at_alias ASC, CHECKSUM_TABLE.ID ASC'
          else
            select_clause = ''
            order_by_clause = 'ORDER BY CHECKSUM_TABLE.ID ASC'
          end

          [select_clause, order_by_clause]
        end

        def build_where_clause(order_column, table_name_sanitized, checksum_calculated_at_sanitized)
          return '' unless ALLOWED_ORDER_COLUMNS.map(&:downcase).include?(order_column.downcase)

          "WHERE #{table_name_sanitized}.#{order_column.downcase} < #{checksum_calculated_at_sanitized}"
        end
      end
    end
  end
end
