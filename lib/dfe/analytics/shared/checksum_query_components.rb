# components used by checksum calculator
module ChecksumQueryComponents
  WHERE_CLAUSE_ORDER_COLUMNS = %w[CREATED_AT UPDATED_AT].freeze

  def build_where_clause(order_column, table_name_sanitized, checksum_calculated_at_sanitized)
    return '' unless WHERE_CLAUSE_ORDER_COLUMNS.map(&:downcase).include?(order_column.downcase)

    "WHERE #{table_name_sanitized}.#{order_column.downcase} < #{checksum_calculated_at_sanitized}"
  end
end
