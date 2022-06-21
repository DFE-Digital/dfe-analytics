# frozen_string_literal: true

module DfE
  module Analytics
    class LoadEntities
      DEFAULT_SLEEP_TIME = 2
      DEFAULT_BATCH_SIZE = 200

      def initialize(model_name:, start_at_id: 0, sleep_time: DEFAULT_SLEEP_TIME, batch_size: DEFAULT_BATCH_SIZE)
        @model_class = Object.const_get(model_name)
        @sleep_time  = sleep_time.to_i
        @batch_size  = batch_size.to_i
        @starting_id = start_at_id
      end

      def run
        Rails.logger.info("Processing data for #{@model_class.name} with row count #{@model_class.count}")

        processed_so_far = 0

        @model_class.order(:id).where('id >= ?', @starting_id).find_in_batches(batch_size: @batch_size) do |records|
          id = records.first.id

          events = records.map do |record|
            DfE::Analytics::Event.new
                                 .with_type('import_entity')
                                 .with_entity_table_name(@model_class.table_name)
                                 .with_data(DfE::Analytics.extract_model_attributes(record))
          end

          DfE::Analytics::SendEvents.do(events.as_json)

          processed_so_far += records.count

          sleep @sleep_time
        rescue StandardError => e
          Rails.logger.info("Process failed while processing #{@model_class.name} within the id range #{id} to #{id + @batch_size}")
          Rails.logger.info(e.message)
        end

        Rails.logger.info "Processed #{processed_so_far} records importing #{@model_class.name}"
      end
    end
  end
end
