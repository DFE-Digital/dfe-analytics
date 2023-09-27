# frozen_string_literal: true

require 'active_support/values/time_zone'

module DfE
  module Analytics
    class Event
      EVENT_TYPES = %w[
        web_request create_entity update_entity delete_entity import_entity initialise_analytics entity_table_check
      ].freeze

      def initialize
        time_zone = 'London'

        @event_hash = {
          environment: DfE::Analytics.environment,
          occurred_at: Time.now.in_time_zone(time_zone).iso8601(6)
        }
      end

      def as_json
        @event_hash.as_json
      end

      def with_type(type)
        allowed_types = EVENT_TYPES + DfE::Analytics.custom_events
        raise 'Invalid analytics event type' unless allowed_types.include?(type.to_s)

        @event_hash.merge!(event_type: type)

        self
      end

      def with_request_details(rack_request)
        @event_hash.merge!(
          request_uuid: rack_request.uuid,
          request_user_agent: ensure_utf8(rack_request.user_agent),
          request_method: rack_request.method,
          request_path: ensure_utf8(rack_request.path),
          request_query: hash_to_kv_pairs(Rack::Utils.parse_query(rack_request.query_string)),
          request_referer: ensure_utf8(rack_request.referer),
          anonymised_user_agent_and_ip: anonymised_user_agent_and_ip(rack_request)
        )

        self
      end

      def with_response_details(rack_response)
        @event_hash.merge!(
          response_content_type: rack_response.content_type,
          response_status: rack_response.status
        )

        self
      end

      def with_user(user)
        @event_hash.merge!(user_id: user_identifier_for(user))

        self
      end

      def with_namespace(namespace)
        @event_hash.merge!(namespace: namespace)

        self
      end

      def with_entity_table_name(table_name)
        @event_hash.merge!(entity_table_name: table_name)

        self
      end

      def with_data(hash)
        @event_hash.deep_merge!(data: hash_to_kv_pairs(hash))

        self
      end

      def with_tags(tags)
        @event_hash[:event_tags] = tags if tags

        self
      end

      def with_request_uuid(request_id)
        @event_hash[:request_uuid] = request_id if request_id

        self
      end

      def byte_size_in_transit
        as_json.to_json.size
      end

      private

      def convert_value_to_json(value)
        value = value.try(:as_json)

        if value.in? [true, false]
          value.to_s
        elsif value.is_a?(Hash)
          value.to_json
        else
          value
        end
      end

      def hash_to_kv_pairs(hash)
        hash.map do |(key, values)|
          if Array.wrap(values).any?(&:nil?)
            message = "an array field contains nulls - event: #{@event_hash} key: #{key} values: #{values}"

            Rails.logger.warn("DfE::Analytics #{message} - This indicates data problems in the app")
          end

          values_as_json = Array.wrap(values).compact.map { |value| convert_value_to_json(value) }

          { 'key' => key, 'value' => values_as_json }
        end
      end

      def anonymised_user_agent_and_ip(rack_request)
        DfE::Analytics.pseudonymise(rack_request.user_agent.to_s + rack_request.remote_ip.to_s) if rack_request.remote_ip.present?
      end

      def ensure_utf8(str)
        str&.scrub
      end

      def user_identifier_for(user)
        user_id = DfE::Analytics.user_identifier(user)
        user_id = DfE::Analytics.pseudonymise(user_id) if user_id.present? && DfE::Analytics.config.pseudonymise_web_request_user_id

        user_id
      end
    end
  end
end
