require_relative '../shared/service_pattern'
require_relative '../services/checksum_calculator'

module DfE
  module Analytics
    module Services
      # Performs checks and calculations on an entity's database table
      class EntityTableChecks
        include ServicePattern

        TIME_ZONE = 'London'.freeze

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
          result = connection.select_all('SELECT CURRENT_TIMESTAMP AS current_timestamp')
          result.first['current_timestamp'].in_time_zone(TIME_ZONE).iso8601(6)
        end

        def id_column_exists_for_entity?(entity_name)
          return true if connection.column_exists?(entity_name, :id)

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
          if connection.column_exists?(entity_name, :updated_at) && columns.include?('updated_at')
            'UPDATED_AT'
          elsif connection.column_exists?(entity_name, :created_at) && columns.include?('created_at')
            'CREATED_AT'
          elsif connection.column_exists?(entity_name, :id) && columns.include?('id')
            'ID'
          else
            Rails.logger.info("DfE::Analytics: Entity checksum: Order column missing in #{entity_name}")
          end
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
          return unless DfE::Analytics.enabled?

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
            .with_data(entity_table_check_data(entity_name, order_column))
            .as_json
        end
      end
    end
  end
end
