# frozen_string_literal: true

# Logic shared between entity_table_check and import_entity_table_check
module ChecksumLogic
  TIME_ZONE = 'London'

  def fetch_current_timestamp_in_time_zone
    result = ActiveRecord::Base.connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp')
    result.first['current_timestamp'].in_time_zone(TIME_ZONE).iso8601(6)
  end

  def supported_adapter_and_environment?
    return true if adapter_name == 'postgresql' || !Rails.env.production?

    Rails.logger.info('DfE::Analytics: Entity checksum: Only Postgres databases supported on PRODUCTION')

    false
  end

  def entity_table_check_data(entity, order_column)
    checksum_calculated_at = fetch_current_timestamp_in_time_zone

    row_count, checksum = fetch_checksum_data(entity, checksum_calculated_at, order_column)
    Rails.logger.info("DfE::Analytics Processing entity: #{entity}: Row count: #{row_count}")
    {
      row_count: row_count,
      checksum: checksum,
      checksum_calculated_at: checksum_calculated_at,
      order_column: order_column
    }
  end

  def determine_order_column(entity, columns)
    if ActiveRecord::Base.connection.column_exists?(entity, :updated_at) && columns.include?('updated_at')
      'UPDATED_AT'
    elsif ActiveRecord::Base.connection.column_exists?(entity, :created_at) && columns.include?('created_at')
      'CREATED_AT'
    else
      Rails.logger.info("DfE::Analytics: Entity checksum: Order column missing in #{entity}")
    end
  end

  def order_column_exposed_for_entity?(entity, columns)
    return false if columns.nil?
    return true if columns.include?('updated_at') || columns.include?('created_at')

    Rails.logger.info("DfE::Analytics Processing entity: Order columns missing in analytics.yml for #{entity} - Skipping checks")

    false
  end

  def id_column_exists_for_entity?(entity)
    return true if ActiveRecord::Base.connection.column_exists?(entity, :id)

    Rails.logger.info("DfE::Analytics: Entity checksum: ID column missing in #{entity} - Skipping checks")

    false
  end

  def adapter_name
    @adapter_name ||= ActiveRecord::Base.connection.adapter_name.downcase
  end

  def fetch_checksum_data(entity, checksum_calculated_at, order_column)
    table_name_sanitized = ActiveRecord::Base.connection.quote_table_name(entity)
    checksum_calculated_at_sanitized = ActiveRecord::Base.connection.quote(checksum_calculated_at)

    if adapter_name == 'postgresql'
      fetch_postgresql_checksum_data(table_name_sanitized, checksum_calculated_at_sanitized, order_column)
    else
      fetch_generic_checksum_data(table_name_sanitized, checksum_calculated_at_sanitized, order_column)
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
