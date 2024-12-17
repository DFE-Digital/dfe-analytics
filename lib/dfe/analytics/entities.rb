# frozen_string_literal: true

module DfE
  module Analytics
    module Entities
      extend ActiveSupport::Concern

      included do
        attr_accessor :event_tags

        after_create_commit do
          extracted_attributes = DfE::Analytics.extract_model_attributes(self)
          send_event('create_entity', extracted_attributes) if extracted_attributes.any?
        end

        after_destroy_commit do
          extracted_attributes = DfE::Analytics.extract_model_attributes(self)
          send_event('delete_entity', extracted_attributes) if extracted_attributes.any?
        end

        after_update_commit do
          # in this after_update hook we don't have access to the new fields via
          # #attributes — we need to dig them out of saved_changes which stores
          # them in the format { attr: ['old', 'new'] }
          updated_attributes = DfE::Analytics.extract_model_attributes(
            self, saved_changes.transform_values(&:last)
          )

          allowed_attributes = DfE::Analytics.extract_model_attributes(self).deep_merge(updated_attributes)

          send_event('update_entity', allowed_attributes) if updated_attributes.any?
        end
      end

      def filter_event_attributes(data)
        data
      end

      def send_event(type, data)
        return unless DfE::Analytics.enabled?

        event = DfE::Analytics::Event.new
                                     .with_type(type)
                                     .with_entity_table_name(self.class.table_name)
                                     .with_data(filter_event_attributes(data))
                                     .with_tags(event_tags)
                                     .with_request_uuid(RequestLocals.fetch(:dfe_analytics_request_id) { nil })

        DfE::Analytics::SendEvents.do([event.as_json])
      end
    end
  end
end
