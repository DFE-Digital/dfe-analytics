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
          trans_attributes = {}
          transaction_changed_attributes.each_key do |name|
            trans_attributes.merge!(name => send(name))
          end
          transaction_attrs = DfE::Analytics.extract_model_attributes(self, trans_attributes)

          updated_attributes = DfE::Analytics.extract_model_attributes(
            self, saved_changes.transform_values(&:last)
          )
          Rails.logger.info("log_previous_changes: #{previous_changes}")
          Rails.logger.info("log_saved_changes: #{saved_changes}")
          Rails.logger.info("log_trans_changes: #{trans_attributes}")
          Rails.logger.info("log_transaction_attrs: #{transaction_attrs}")
          Rails.logger.info("log_updated_attributes: #{updated_attributes}")
          Rails.logger.info("log_model: #{self}")
          allowed_attributes = DfE::Analytics.extract_model_attributes(self).deep_merge(updated_attributes)

          send_event('update_entity', allowed_attributes) if updated_attributes.any?
        end
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
