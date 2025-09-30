# frozen_string_literal: true
=begin
module DfE
  module Analytics
    class LoadEntities
      # from https://cloud.google.com/bigquery/quotas#streaming_inserts
      BQ_BATCH_ROWS = 500

      def initialize(entity_name:)
        @entity_name = entity_name
      end

      attr_reader :entity_name

      def run(entity_tag:)
        DfE::Analytics.models_for_entity(entity_name).map do |model|
          unless model.any?
            Rails.logger.info("No entities to process for #{entity_name}")
            next
          end

          primary_key = model.primary_key

          if primary_key.nil?
            Rails.logger.info("Not processing #{entity_name} as it does not have a primary key")
            next
          end

          unless primary_key.to_sym == :id
            Rails.logger.info("Not processing #{entity_name} as we do not support non-id primary keys")
            next
          end

          Rails.logger.info("Processing data for #{entity_name} with row count #{model.count}")

          batch_count = 0

          model.in_batches(of: BQ_BATCH_ROWS) do |relation|
            batch_count += 1
            ids = relation.pluck(:id)
            DfE::Analytics::LoadEntityBatch.perform_later(model.to_s, ids, entity_tag)
          end
          Rails.logger.info "Enqueued #{batch_count} batches of #{BQ_BATCH_ROWS} #{entity_name} records for importing to BigQuery"
        end
      end
    end
  end
end
=end
# frozen_string_literal: true

module DfE
  module Analytics
    class LoadEntities
      # from https://cloud.google.com/bigquery/quotas#streaming_inserts
      BQ_BATCH_ROWS = 500

      def initialize(entity_name:)
        @entity_name = entity_name
      end

      attr_reader :entity_name

      def run(entity_tag:)
        DfE::Analytics.models_for_entity(entity_name).each do |model|
          if DfE::Analytics.config.ignore_default_scope && model.respond_to?(:unscoped)
            model.unscoped { process_model(model, entity_tag) }
          else
            process_model(model, entity_tag)
          end
        end
      end

      private

      def process_model(model, entity_tag)
        unless model.any?
          Rails.logger.info("No entities to process for #{entity_name}")
          return
        end

        primary_key = model.primary_key

        if primary_key.nil?
          Rails.logger.info("Not processing #{entity_name} as it does not have a primary key")
          return
        end

        unless primary_key.to_sym == :id
          Rails.logger.info("Not processing #{entity_name} as we do not support non-id primary keys")
          return
        end

        Rails.logger.info("Processing data for #{entity_name} with row count #{model.count}")

        batch_count = 0
        model.in_batches(of: BQ_BATCH_ROWS) do |relation|
          batch_count += 1
          ids = relation.pluck(:id)
          DfE::Analytics::LoadEntityBatch.perform_later(model.to_s, ids, entity_tag)
        end

        Rails.logger.info "Enqueued #{batch_count} batches of #{BQ_BATCH_ROWS} #{entity_name} records for importing to BigQuery"
      end
    end
  end
end
