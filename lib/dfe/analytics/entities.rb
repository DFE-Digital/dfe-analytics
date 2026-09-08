# frozen_string_literal: true

module DfE
  module Analytics
    module Entities
      extend ActiveSupport::Concern

      included do
        attr_accessor :event_tags

        after_create_commit :send_create_entity_event,
                            if: -> { DfE::Analytics.database_events_enabled? }

        after_destroy_commit :send_delete_entity_event,
                             if: -> { DfE::Analytics.database_events_enabled? }

        after_update_commit :send_update_entity_event,
                            if: -> { DfE::Analytics.database_events_enabled? }
      end

      def send_create_entity_event
        extracted_attributes = DfE::Analytics.extract_model_attributes(self)
        send_event('create_entity', extracted_attributes) if extracted_attributes.any?
      end

      def send_delete_entity_event
        extracted_attributes = DfE::Analytics.extract_model_attributes(self)
        send_event('delete_entity', extracted_attributes) if extracted_attributes.any?
      end

      def send_update_entity_event
        # in this after_update hook we don't have access to the new fields via
        # attributes or saved changes in transactions, so we use the
        # TransactionChanges module

        updated_attributes = DfE::Analytics.extract_model_attributes(self, changed_attributes_for_dfe_analytics)

        allowed_attributes = DfE::Analytics.extract_model_attributes(self).deep_merge(updated_attributes)

        send_event('update_entity', allowed_attributes) if updated_attributes.any?
      end

      def changed_attributes_for_dfe_analytics
        transaction_changed_attributes.keys.index_with { send(_1) }
      end

      def send_event(type, data)
        return unless DfE::Analytics.enabled?

        event = DfE::Analytics::Event.new
                                     .with_type(type)
                                     .with_entity_table_name(self.class.table_name)
                                     .with_data(data)
                                     .with_tags(event_tags)
                                     .with_request_uuid(RequestLocals.fetch(:dfe_analytics_request_id) { nil })

        DfE::Analytics::SendEvents.do([event.as_json])
      end
    end
  end
end
