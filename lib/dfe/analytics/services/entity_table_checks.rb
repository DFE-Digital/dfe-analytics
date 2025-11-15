# frozen_string_literal: true

module DfE
  module Analytics
    module Services
      # Performs checks and calculations on an entity's database table
      class EntityTableChecks
        include ServicePattern

        TIME_ZONE = 'London'

        def initialize(entity_name:, entity_type:, entity_tag: nil)
          @entity_name = entity_name
          @entity_type = entity_type
          @entity_tag = entity_tag
          @connection = ActiveRecord::Base.connection
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

        attr_reader :entity_name, :entity_type, :entity_tag, :connection

        def adapter_name
          @adapter_name ||= connection.adapter_name.downcase
        end

        def supported_adapter_and_environment?
          return true if %w[postgresql postgis].include?(adapter_name) || !Rails.env.production?

          Rails.logger.info('DfE::Analytics: Entity checksum: Only Postgres databases supported on PRODUCTION')

          false
        end

        def fetch_current_timestamp_in_time_zone
          utc_timestamp = case connection.adapter_name.downcase
                          when 'postgresql', 'postgis'
                            connection.select_value("SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::text AS current_timestamp_utc")
                          when 'sqlite3', 'sqlite'
                            connection.select_value('SELECT CURRENT_TIMESTAMP AS current_timestamp_utc')
                          end

          if utc_timestamp.present?
            Time.use_zone(TIME_ZONE) do
              utc_time = Time.find_zone('UTC').parse(utc_timestamp)
              utc_time.in_time_zone(Time.zone).iso8601(6)
            end
          else
            # Fallback: use application clock but make the choice explicit
            Rails.logger.warn("fetch_current_timestamp_in_time_zone: unknown DB adapter '#{connection.adapter_name}', falling back to app clock")
            Time.use_zone(TIME_ZONE) { Time.zone.now.iso8601(6) }
          end
        end

        def id_column_exists_for_entity?(entity_name)
          return true if connection.column_exists?(entity_name, :id)

          Rails.logger.info("DfE::Analytics: Entity checksum: ID column missing in #{entity_name} - Skipping checks")

          false
        end

        def order_column_exposed_for_entity?(entity_name, columns)
          return false if columns.nil?
          return true if columns.any? { |column| %w[created_at id].include?(column) }

          Rails.logger.info("DfE::Analytics Processing entity: Order columns missing in analytics.yml for #{entity_name} - Skipping checks")

          false
        end

        def determine_order_column(entity_name, columns)
          if connection.column_exists?(entity_name, :created_at) && columns.include?('created_at') && !null_values_in_column?('created_at')
            'CREATED_AT'
          elsif connection.column_exists?(entity_name, :id) && columns.include?('id')
            'ID'
          else
            Rails.logger.info("DfE::Analytics: Entity checksum: Order column missing in #{entity_name}")
          end
        end

        def null_values_in_column?(column)
          connection.select_value(<<-SQL).to_i.positive?
            SELECT COUNT(*)
            FROM #{connection.quote_table_name(entity_name)}
            WHERE #{column} IS NULL
          SQL
        end

        def entity_table_check_data(entity_name, order_column)
          checksum_calculated_at = fetch_current_timestamp_in_time_zone

          checksum_result = DfE::Analytics::Services::ChecksumCalculator.call(entity_name, order_column, checksum_calculated_at)
          row_count, checksum = checksum_result

          Rails.logger.info("DfE::Analytics Processing entity: #{entity_name}: Row count: #{row_count}")
          {
            row_count: row_count,
            checksum: checksum,
            checksum_calculated_at: checksum_calculated_at,
            order_column: order_column
          }
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
            .with_tags([entity_tag])
            .with_data(data: entity_table_check_data(entity_name, order_column))
            .as_json
        end
      end
    end
  end
end
