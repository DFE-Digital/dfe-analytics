# frozen_string_literal: true

module DfE
  module Analytics
    # Airbyte stream config generator
    class AirbyteStreamConfig
      CURSOR_FIELD = %w[_ab_cdc_lsn].freeze
      AIRBYTE_FIELDS = %w[_ab_cdc_deleted_at _ab_cdc_updated_at].freeze
      DEFAULT_PRIMARY_KEY = 'id'
      SYNC_MODE = 'incremental_append'

      def self.config
        JSON.parse(File.read(DfE::Analytics.config.airbyte_stream_config_path)).deep_symbolize_keys
      rescue RuntimeError
        {}
      end

      def self.generate_for(entity_attributes)
        JSON.pretty_generate(
          { configurations: { streams: streams_for(entity_attributes) } }
        )
      end

      def self.entity_attributes
        return {} if config.empty?

        # Transform the data
        config[:configurations][:streams].each_with_object({}) do |stream, memo|
          stream_name = stream[:name]
          fields = stream[:selectedFields].map { |field| field[:fieldPath].first }
          memo[stream_name] = fields - CURSOR_FIELD - AIRBYTE_FIELDS
        end.deep_symbolize_keys
      end

      private_class_method def self.streams_for(entity_attributes)
        entity_attributes.each_with_object([]) do |(entity, attributes), streams|
          streams << table_for(entity, attributes)
        end
      end

      private_class_method def self.table_for(entity, attributes)
        {
          name: entity,
          syncMode: SYNC_MODE,
          cursorField: CURSOR_FIELD,
          primaryKey: [[primary_key_for(attributes)]],
          selectedFields: (CURSOR_FIELD + AIRBYTE_FIELDS + attributes).uniq.map { |attribute| { fieldPath: [attribute] } }
        }
      end

      private_class_method def self.primary_key_for(attributes)
        return DEFAULT_PRIMARY_KEY if attributes.include?(DEFAULT_PRIMARY_KEY)

        attributes.first
      end
    end
  end
end
