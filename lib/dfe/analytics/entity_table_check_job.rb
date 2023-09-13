# frozen_string_literal: true

module DfE
  module Analytics
    # Reschedules to run every 24hours
    class EntityTableCheckJob < AnalyticsJob
      WAIT_TIME = 24.hours

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
        reschedule_job
      end

      def entity_table_check_data(model)
        {
          number_of_rows: model.count,
          checksum: checksum(model)
        }
      end

      def reschedule_job
        self.class.set(wait: WAIT_TIME).perform_later
      end

      def checksum(model)
        table_data = model.order(id: :asc)
        concatenated_table_data = table_data.map { |data| data.attributes.to_json }.join
        Digest::SHA256.hexdigest(concatenated_table_data)
      end
    end
  end
end
