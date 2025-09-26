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
          # attributes or saved changes in transactions, so we use the
          # TransactionChanges module

          updated_attributes = DfE::Analytics.extract_model_attributes(self, all_changed_attributes)

          allowed_attributes = DfE::Analytics.extract_model_attributes(self).deep_merge(updated_attributes)

          send_event('update_entity', allowed_attributes) if updated_attributes.any?
        end
      end

      def all_changed_attributes
        changed_attributes = {}
        transaction_changed_attributes.each_key do |name|
          changed_attributes.merge!(name => send(name))
        end
        changed_attributes
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
