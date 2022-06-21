# frozen_string_literal: true

module DfE
  module Analytics
    class LoadEntities
      DEFAULT_BATCH_SIZE = 200

      def initialize(model_name:, batch_size: DEFAULT_BATCH_SIZE)
        @model_name = model_name
        @model_class = Object.const_get(model_name)
        @batch_size  = batch_size.to_i
      end

      def run
        Rails.logger.info("Processing data for #{@model_class.name} with row count #{@model_class.count}")

        batch_number = 0

        @model_class.order(:id).in_batches(of: @batch_size) do |relation|
          batch_number += 1

          ids = relation.pluck(:id)

          DfE::Analytics::LoadEntityBatch.perform_later(@model_class, ids, batch_number)
        end

        Rails.logger.info "Enqueued #{batch_number} batches of #{@batch_size} #{@model_name} for importing to BigQuery"
      end
    end
  end
end
