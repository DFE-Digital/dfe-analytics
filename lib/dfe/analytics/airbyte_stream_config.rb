# frozen_string_literal: true

module DfE
  module Analytics
    # Airbyte stream config generator
    class AirbyteStreamConfig
      CURSOR_FIELD = %w[_ab_cdc_lsn].freeze
      AIRBYTE_FIELDS = %w[_ab_cdc_deleted_at _ab_cdc_updated_at].freeze
      DEFAULT_PRIMARY_KEY = 'id'
      INCREMENTAL_APPEND_SYNC_MODE = 'incremental_append'
      FULL_REFRESH_OVERWRITE_SYNC_MODE = 'full_refresh_overwrite'
      AIRBYTE_HEARTBEAT_ENTITY = 'airbyte_heartbeat'
      AIRBYTE_HEARTBEAT_ATTRIBUTES = %w[id last_heartbeat].freeze
      AIRBYTE_HEARTBEAT_ENTITY_ATTRIBUTES = { AIRBYTE_HEARTBEAT_ENTITY.to_sym => AIRBYTE_HEARTBEAT_ATTRIBUTES }.freeze

      def self.generate_pretty_json_for(table_attributes)
        JSON.pretty_generate(generate_for(table_attributes))
      end

      def self.generate_for(table_attributes)
        { configurations: { streams: streams_for(table_attributes) } }
      end

      def self.entity_attributes
        return {} if DfE::Analytics.airbyte_stream_config.empty?

        # Transform the data
        DfE::Analytics.airbyte_stream_config[:configurations][:streams].each_with_object({}) do |stream, memo|
          stream_name = stream[:name]
          fields = stream[:selectedFields].map { |field| field[:fieldPath].first }
          memo[stream_name] = fields - CURSOR_FIELD - AIRBYTE_FIELDS
        end.deep_symbolize_keys
      end

      private_class_method def self.streams_for(table_attributes)
        table_attributes.each_with_object([]) do |(entity, attributes), streams|
          streams << table_for(entity, attributes)
        end << heartbeat_table
      end

      private_class_method def self.table_for(entity, attributes)
        {
          name: entity.to_s,
          syncMode: INCREMENTAL_APPEND_SYNC_MODE,
          cursorField: CURSOR_FIELD,
          primaryKey: [[primary_key_for(attributes)]],
          selectedFields: (CURSOR_FIELD + AIRBYTE_FIELDS + attributes).uniq.map { |attribute| { fieldPath: [attribute] } }
        }
      end

      private_class_method def self.primary_key_for(attributes)
        return DEFAULT_PRIMARY_KEY if attributes.include?(DEFAULT_PRIMARY_KEY)

        attributes.first
      end

      private_class_method def self.heartbeat_table
        {
          name: AIRBYTE_HEARTBEAT_ENTITY,
          syncMode: FULL_REFRESH_OVERWRITE_SYNC_MODE,
          primaryKey: [[primary_key_for(AIRBYTE_HEARTBEAT_ATTRIBUTES)]],
          selectedFields: AIRBYTE_HEARTBEAT_ATTRIBUTES.map { |attribute| { fieldPath: [attribute] } }
        }
      end
    end
  end
end
