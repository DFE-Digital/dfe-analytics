# frozen_string_literal: true

module DfE
  module Analytics
    module Entities
      extend ActiveSupport::Concern

      included do
        attr_accessor :event_tags

        after_create do
          allowed_data, hidden_data = DfE::Analytics.extract_model_attributes(self)
          send_event('create_entity', allowed_data, hidden_data) if allowed_data.any? || hidden_data.any?
        end

        after_destroy do
          allowed_data, hidden_data = DfE::Analytics.extract_model_attributes(self)
          send_event('delete_entity', allowed_data, hidden_data) if allowed_data.any? || hidden_data.any?
        end

        after_update do
          # in this after_update hook we don’t have access to the new fields via
          # #attributes — we need to dig them out of saved_changes which stores
          # them in the format { attr: ['old', 'new'] }
          allowed_data, hidden_data = DfE::Analytics.extract_model_attributes(
            self, saved_changes.transform_values(&:last)
          )

          send_event('update_entity', DfE::Analytics.extract_model_attributes(self).first.merge(allowed_data), hidden_data) if allowed_data.any? || hidden_data.any?
        end
      end

      def send_event(type, allowed_data, hidden_data = {})
        return unless DfE::Analytics.enabled?

        event = DfE::Analytics::Event.new
                                     .with_type(type)
                                     .with_entity_table_name(self.class.table_name)
                                     .with_data(allowed_data)
                                     .with_hidden_data(hidden_data)
                                     .with_tags(event_tags)
                                     .with_request_uuid(RequestLocals.fetch(:dfe_analytics_request_id) { nil })

        DfE::Analytics::SendEvents.do([event.as_json])
      end
    end
  end
end
