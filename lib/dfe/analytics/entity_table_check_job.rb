# frozen_string_literal: true

require 'active_support/values/time_zone'

module DfE
  module Analytics
    # Reschedules to run every 24hours
    class EntityTableCheckJob < AnalyticsJob
      WAIT_TIME = Date.tomorrow.midnight
      TIME_ZONE = 'London'

      def perform
        DfE::Analytics.entities_for_analytics.each do |entity_name|
          DfE::Analytics.models_for_entity(entity_name).each do |model|
            entity_table_check_event = DfE::Analytics::Event.new
                                                            .with_type('entity_table_check')
                                                            .with_entity_table_name(model.table_name)
                                                            .with_data(entity_table_check_data(model))
                                                            .as_json
            DfE::Analytics::SendEvents.perform_later([entity_table_check_event])
            Rails.logger.info("Processing data for #{model.table_name} with row count #{model.count}")
          end
        end
      ensure
        reschedule_job
      end

      def entity_table_check_data(model)
        {
          number_of_rows: model.count,
          checksum: checksum_data(model)[:checksum],
          timestamp: checksum_data(model)[:timestamp]
        }
      end

      def reschedule_job
        self.class.set(wait_until: WAIT_TIME).perform_later
      end

      def checksum_data(model)
        table_ids = model.order(id: :asc).pluck(:id).join
        {
          checksum: Digest::SHA256.hexdigest(table_ids),
          timestamp: Time.now.in_time_zone(TIME_ZONE).iso8601(6)
        }
      end
    end
  end
end
