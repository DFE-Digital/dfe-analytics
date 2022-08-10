module DfE
  module Analytics
    class LoadEntityBatch < AnalyticsJob
      def perform(model_class, ids, batch_number)
        # Support string args for Rails < 6.1
        model_class = model_class.constantize if model_class.respond_to?(:constantize)

        events = model_class.where(id: ids).map do |record|
          DfE::Analytics::Event.new
            .with_type('import_entity')
            .with_entity_table_name(model_class.table_name)
            .with_data(DfE::Analytics.extract_model_attributes(record))
        end

        DfE::Analytics::SendEvents.perform_now(events.as_json)

        Rails.logger.info "Enqueued batch #{batch_number} of #{model_class.table_name}"
      end
    end
  end
end
