require_relative '../shared/service_pattern'
# rubocop:disable Metrics/ClassLength
module DfE
  module Analytics
    module Services
      # The EntityTableChecks class is responsible for performing checks
      # and calculations on a given entity's database table
      class EntityTableChecks
        include ServicePattern

        TIME_ZONE = 'London'.freeze

        def initialize(entity_name:, entity_type:, entity_tag: nil)
          @entity_name = entity_name
          @entity_type = entity_type
          @entity_tag = entity_tag
        end

        def call
          return unless supported_adapter_and_environment?
          return unless id_column_exists_for_entity?(@entity_name)

          columns = DfE::Analytics.allowlist[@entity_name]
          return unless order_column_exposed_for_entity?(@entity_name, columns)

          order_column = determine_order_column(@entity_name, columns)
          send_entity_table_check_event(@entity_name, @entity_type, @entity_tag, order_column)
        end

        private

        attr_reader :entity_name, :entity_type, :entity_tag

        def adapter_name
          @adapter_name ||= ActiveRecord::Base.connection.adapter_name.downcase
        end

        def supported_adapter_and_environment?
          return true if @adapter_name == 'postgresql' || !Rails.env.production?

          Rails.logger.info('DfE::Analytics: Entity checksum: Only Postgres databases supported on PRODUCTION')

          false
        end

        def fetch_current_timestamp_in_time_zone
          result = ActiveRecord::Base.connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp')
          result.first['current_timestamp'].in_time_zone(TIME_ZONE).iso8601(6)
        end

        def id_column_exists_for_entity?(entity_name)
          return true if ActiveRecord::Base.connection.column_exists?(entity_name, :id)

          Rails.logger.info("DfE::Analytics: Entity checksum: ID column missing in #{entity_name} - Skipping checks")

          false
        end

        def order_column_exposed_for_entity?(entity_name, columns)
          return false if columns.nil?
          return true if columns.any? { |column| %w[updated_at created_at id].include?(column) }

          Rails.logger.info("DfE::Analytics Processing entity: Order columns missing in analytics.yml for #{entity_name} - Skipping checks")

          false
        end

        def determine_order_column(entity_name, columns)
          if ActiveRecord::Base.connection.column_exists?(entity_name, :updated_at) && columns.include?('updated_at')
            'UPDATED_AT'
          elsif ActiveRecord::Base.connection.column_exists?(entity_name, :created_at) && columns.include?('created_at')
            'CREATED_AT'
          elsif ActiveRecord::Base.connection.column_exists?(entity_name, :id) && columns.include?('id')
            'ID'
          else
            Rails.logger.info("DfE::Analytics: Entity checksum: Order column missing in #{entity_name}")
          end
        end

        def entity_table_check_data(entity_name, order_column)
          checksum_calculated_at = fetch_current_timestamp_in_time_zone

          row_count, checksum = fetch_checksum_data(entity_name, checksum_calculated_at, order_column)
          Rails.logger.info("DfE::Analytics Processing entity: #{entity_name}: Row count: #{row_count}")
          {
            row_count: row_count,
            checksum: checksum,
            checksum_calculated_at: checksum_calculated_at,
            order_column: order_column
          }
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
          where_clause = build_where_clause(table_name_sanitized, checksum_calculated_at_sanitized, order_column)

          checksum_sql_query = <<-SQL
            SELECT COUNT(*) as row_count,
              MD5(COALESCE(STRING_AGG(CHECKSUM_TABLE.ID, '' ORDER BY CHECKSUM_TABLE.#{order_column.downcase} ASC), '')) as checksum
            FROM (
              SELECT #{table_name_sanitized}.id::TEXT as ID,
                     #{table_name_sanitized}.#{order_column.downcase} as #{order_column.downcase}
              FROM #{table_name_sanitized}
              #{where_clause}
            ) CHECKSUM_TABLE
          SQL

          result = ActiveRecord::Base.connection.execute(checksum_sql_query).first
          [result['row_count'].to_i, result['checksum']]
        end

        def fetch_generic_checksum_data(table_name_sanitized, checksum_calculated_at_sanitized, order_column)
          where_clause = build_where_clause(table_name_sanitized, checksum_calculated_at_sanitized, order_column)

          checksum_sql_query = <<-SQL
            SELECT #{table_name_sanitized}.ID
            FROM #{table_name_sanitized}
            #{where_clause}
            ORDER BY #{table_name_sanitized}.#{order_column} ASC
          SQL

          table_ids = ActiveRecord::Base.connection.execute(checksum_sql_query).pluck('id')
          [table_ids.count, Digest::MD5.hexdigest(table_ids.join)]
        end

        def build_where_clause(table_name_sanitized, checksum_calculated_at_sanitized, order_column)
          return '' unless %w[CREATED_AT UPDATED_AT].include?(order_column)

          "WHERE #{table_name_sanitized}.#{order_column.downcase} < #{checksum_calculated_at_sanitized}"
        end

        def send_entity_table_check_event(entity_name, entity_type, entity_tag, order_column)
          entity_table_check_event = build_event_for(entity_name, entity_type, entity_tag, order_column)
          DfE::Analytics::SendEvents.perform_later([entity_table_check_event])
        end

        def build_event_for(entity_name, entity_type, entity_tag, order_column)
          unless DfE::Analytics.models_for_entity(entity_name).any?
            Rails.logger.info("DfE::Analytics NOT Processing entity: #{entity_name} - No associated models")
            return
          end

          DfE::Analytics::Event.new
            .with_type(entity_type)
            .with_entity_table_name(entity_name)
            .with_tags(entity_tag)
            .with_data(entity_table_check_data(entity_name, order_column))
            .as_json
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
