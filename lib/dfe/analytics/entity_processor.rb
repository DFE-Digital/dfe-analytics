require_relative 'shared/checksum_logic'

module DfE
  module Analytics
    # Processes entities by sending the import_entity_check_event
    class EntityProcessor
      extend ChecksumLogic

      def self.process_entity_for_import(entity_name, import_entity_id)
        return unless supported_adapter_and_environment?
        return unless id_column_exists_for_entity?(entity_name)

        columns = DfE::Analytics.allowlist[entity_name]
        return unless order_column_exposed_for_entity?(entity_name, columns)
        order_column = determine_order_column(entity_name, columns)

        send_import_entity_table_check_event(entity_name, import_entity_id, order_column)
      end

      def self.send_import_entity_table_check_event(entity_name, import_entity_id, order_column)
        import_entity_table_check_event = build_event_for(entity_name, import_entity_id, order_column)
        DfE::Analytics::SendEvents.perform_later([import_entity_table_check_event])
      end

      def self.build_event_for(entity_name, import_entity_id, order_column)
        DfE::Analytics::Event.new
          .with_type('import_entity_table_check')
          .with_entity_table_name(entity_name)
          .with_tags(import_entity_id)
          .with_data(entity_table_check_data(entity_name, order_column))
          .as_json
      end
    end
  end
end
