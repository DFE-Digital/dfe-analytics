# frozen_string_literal: true

module Services
  module Airbyte
    # Fetches the the current schema for given source - Also reloads cache
    class ConnectionUpdate
      CURSOR_FIELD = %w[_ab_cdc_lsn].freeze
      AIRBYTE_FIELDS = %w[_ab_cdc_deleted_at _ab_cdc_updated_at].freeze
      DEFAULT_PRIMARY_KEY = 'id'
      SYNC_MODE = 'incremental_append'
      DESTINATION_SYNC_MODE = 'append'

      class Error < StandardError; end

      def self.call(access_token:, allowed_list:)
        new(access_token, allowed_list).call
      end

      def initialize(access_token, allowed_list)
        raise Error, 'allowed_list must be a Hash of table_name => fields' unless allowed_list.is_a?(Hash)

        @access_token = access_token
        @allowed_list = allowed_list
        @connection_id = DfE::Analytics.config.airbyte_configuration[:connection_id]
      end

      def call
        Services::Airbyte::ApiServer.patch(
          path: "/api/public/v1/connections/#{@connection_id}",
          access_token: @access_token,
          payload: connection_patch_payload
        )
      end

      private

      def connection_patch_payload
        {
          configurations: {
            streams: @allowed_list.map do |stream_name, fields|
              {
                name: stream_name.to_s,
                selected: true,
                syncMode: SYNC_MODE,
                cursorField: CURSOR_FIELD,
                primaryKey: [[DEFAULT_PRIMARY_KEY]],
                selectedFields: selected_fields(fields)
              }
            end
          }
        }
      end

      def selected_fields(fields)
        (CURSOR_FIELD + AIRBYTE_FIELDS + fields).uniq.map do |field|
          { fieldPath: [field] }
        end
      end
    end
  end
end
