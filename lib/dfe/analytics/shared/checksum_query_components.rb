# components used by checksum calculator
module ChecksumQueryComponents
  WHERE_CLAUSE_ORDER_COLUMNS = %w[CREATED_AT UPDATED_AT].freeze

  def build_select_and_order_clause(order_column, table_name_sanitized)
    case order_column
    when 'updated_at'
      select_clause = "#{table_name_sanitized}.updated_at as updated_at_alias"
      order_by_clause = "updated_at_alias ASC, #{table_name_sanitized}.ID ASC"
    when 'created_at'
      select_clause = "#{table_name_sanitized}.created_at as created_at_alias"
      order_by_clause = "created_at_alias ASC, #{table_name_sanitized}.ID ASC"
    else
      select_clause = ''
      order_by_clause = "#{table_name_sanitized}.ID ASC"
    end

    [select_clause, order_by_clause]
  end

  def build_where_clause(order_column, table_name_sanitized, checksum_calculated_at_sanitized)
    return '' unless WHERE_CLAUSE_ORDER_COLUMNS.map(&:downcase).include?(order_column.downcase)

    "WHERE #{table_name_sanitized}.#{order_column.downcase} < #{checksum_calculated_at_sanitized}"
  end
end
