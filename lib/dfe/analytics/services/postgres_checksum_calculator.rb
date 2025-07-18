require_relative '../shared/service_pattern'

module DfE
  module Analytics
    module Services
      # Calculates a checksum and row count for a specified entity
      # and order column in a PostgreSQL database
      class PostgresChecksumCalculator
        include ServicePattern

        def initialize(entity, order_column, checksum_calculated_at)
          @entity = entity
          @order_column = order_column
          @checksum_calculated_at = checksum_calculated_at
          @connection = ActiveRecord::Base.connection
        end

        def call
          ActiveRecord::Base.transaction do
            calculate_checksum
          end
        end

        private

        attr_reader :entity, :order_column, :checksum_calculated_at, :connection

        def calculate_checksum
          table_name_sanitized = connection.quote_table_name(entity)
          checksum_calculated_at_sanitized = connection.quote(checksum_calculated_at)
          where_clause = build_where_clause(order_column, table_name_sanitized, checksum_calculated_at_sanitized)
          select_clause, order_alias = build_select_and_order_clause(order_column, table_name_sanitized)

          checksum_sql_query = <<-SQL
          SELECT COUNT(*) as row_count,
            MD5(COALESCE(STRING_AGG(CHECKSUM_TABLE.ID, '' ORDER BY CHECKSUM_TABLE.#{order_alias} ASC, CHECKSUM_TABLE.ID ASC), '')) as checksum
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
          order_alias = case order_column
                        when 'CREATED_AT'
                          "#{order_column.downcase}_alias"
                        else
                          'id_alias'
                        end
          select_clause = case order_column
                          when 'CREATED_AT'
                            "DATE_TRUNC('milliseconds', #{table_name_sanitized}.#{order_column.downcase}) AS \"#{order_alias}\""
                          else
                            "#{table_name_sanitized}.id::TEXT AS \"#{order_alias}\""
                          end
          [select_clause, order_alias]
        end

        def build_where_clause(order_column, table_name_sanitized, checksum_calculated_at_sanitized)
          return '' unless order_column.downcase == 'created_at'

          # Add IS NULL to include records with null created_at values
          "WHERE (#{table_name_sanitized}.#{order_column.downcase} IS NULL OR DATE_TRUNC('milliseconds', #{table_name_sanitized}.#{order_column.downcase}) < DATE_TRUNC('milliseconds', #{checksum_calculated_at_sanitized}::timestamp))"
        end
      end
    end
  end
end
