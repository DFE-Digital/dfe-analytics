# frozen_string_literal: true

require 'active_support/values/time_zone'

module DfE
  module Analytics
    class Event
      EVENT_TYPES = %w[web_request create_entity update_entity delete_entity import_entity].freeze

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
        raise 'Invalid analytics event type' unless EVENT_TYPES.include?(type.to_s)

        @event_hash.merge!(
          event_type: type
        )

        self
      end

      def with_request_details(rack_request)
        @event_hash.merge!(
          request_uuid: rack_request.uuid,
          request_user_agent: rack_request.user_agent,
          request_method: rack_request.method,
          request_path: rack_request.path,
          request_query: hash_to_kv_pairs(Rack::Utils.parse_query(rack_request.query_string)),
          request_referer: rack_request.referer,
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
        @event_hash.merge!(
          user_id: user&.id
        )

        self
      end

      def with_namespace(namespace)
        @event_hash.merge!(
          namespace: namespace
        )

        self
      end

      def with_entity_table_name(table_name)
        @event_hash.merge!(
          entity_table_name: table_name
        )

        self
      end

      def with_data(hash)
        @event_hash.deep_merge!({
                                  data: hash_to_kv_pairs(hash)
                                })

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

      private

      def hash_to_kv_pairs(hash)
        hash.map do |(key, value)|
          if value.in? [true, false]
            value = value.to_s
          elsif value.is_a?(Hash)
            value = value.to_json
          end

          { 'key' => key, 'value' => Array.wrap(value) }
        end
      end

      def anonymised_user_agent_and_ip(rack_request)
        anonymise(rack_request.user_agent.to_s + rack_request.remote_ip.to_s) if rack_request.remote_ip.present?
      end

      def anonymise(text)
        Digest::SHA2.hexdigest(text)
      end
    end
  end
end
