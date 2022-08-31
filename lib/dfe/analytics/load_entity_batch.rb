module DfE
  module Analytics
    class LoadEntityBatch < AnalyticsJob
      # https://cloud.google.com/bigquery/quotas#streaming_inserts
      # at a batch size of 500, this allows 20kb per record
      BQ_BATCH_MAX_BYTES = 10_000_000

      def perform(model_class_arg, ids)
        # Support string args for Rails < 6.1
        model_class = if model_class_arg.respond_to?(:constantize)
                        model_class_arg.constantize
                      else
                        model_class_arg
                      end

        events = model_class.where(id: ids).map do |record|
          DfE::Analytics::Event.new
            .with_type('import_entity')
            .with_entity_table_name(model_class.table_name)
            .with_data(DfE::Analytics.extract_model_attributes(record))
        end

        payload_byte_size = events.sum(&:byte_size_in_transit)

        # if we overrun the max batch size, recurse with each half of the list
        if payload_byte_size > BQ_BATCH_MAX_BYTES
          ids.each_slice((ids.size / 2.0).round).to_a.each do |half_batch|
            Rails.logger.info "Halving batch of size #{payload_byte_size} for #{model_class.name}"
            self.class.perform_later(model_class_arg, half_batch)
          end
        else
          DfE::Analytics::SendEvents.perform_now(events.as_json)
        end
      end
    end
  end
end
