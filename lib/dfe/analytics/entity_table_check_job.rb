# frozen_string_literal: true

require 'active_support/values/time_zone'
require 'yaml'

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
        reschedule_job if allow_reschedule?
      end

      def entity_table_check_data(model)
        checksum_calculated_at = Time.now.in_time_zone(TIME_ZONE).iso8601(6)
        table_ids = model.where('updated_at < ?', Time.parse(checksum_calculated_at))
        {
          row_count: table_ids.size,
          checksum: Digest::SHA256.hexdigest(table_ids.order(updated_at: :asc).pluck(:id).join),
          checksum_calculated_at: checksum_calculated_at
        }
      end

      def reschedule_job
        self.class.set(wait_until: WAIT_TIME).perform_later
      end

      def allow_reschedule?
        config = YAML.load_file(Rails.root.join('config', 'analytics_config.yml'))
        config['enable_entity_table_check_job']
      end
    end
  end
end
