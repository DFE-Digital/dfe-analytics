# frozen_string_literal: true

module DfE
  module Analytics
    class LoadEntities
      DEFAULT_BATCH_SIZE = 200

      def initialize(entity_name:, batch_size: DEFAULT_BATCH_SIZE)
        @entity_name = entity_name
        @batch_size  = batch_size.to_i
      end

      def run
        model = DfE::Analytics.model_for_entity(@entity_name)
        Rails.logger.info("Processing data for #{@entity_name} with row count #{model.count}")

        batch_number = 0

        model.order(:id).in_batches(of: @batch_size) do |relation|
          batch_number += 1

          ids = relation.pluck(:id)

          DfE::Analytics::LoadEntityBatch.perform_later(model.to_s, ids, batch_number)
        end

        Rails.logger.info "Enqueued #{batch_number} batches of #{@batch_size} #{@entity_name} for importing to BigQuery"
      end
    end
  end
end
