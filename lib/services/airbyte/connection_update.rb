# frozen_string_literal: true

module Services
  module Airbyte
    # Fetches the the current schema for given source - Also reloads cache
    class ConnectionUpdate
      CURSOR_FIELD = %w[_ab_cdc_lsn].freeze
      AIRBYTE_FIELDS = %w[_ab_cdc_deleted_at _ab_cdc_updated_at].freeze
      DEFAULT_PRIMARY_KEY = 'id'
      SYNC_MODE = 'incremental'
      DESTINATION_SYNC_MODE = 'append'

      class Error < StandardError; end

      def self.call(access_token:, connection_id:, allowed_list:, discovered_schema:)
        new(access_token, connection_id, allowed_list, discovered_schema).call
      end

      def initialize(access_token, connection_id, allowed_list, discovered_schema)
        @access_token = access_token
        @connection_id = connection_id
        @allowed_list = allowed_list
        @discovered_streams = discovered_schema&.dig('catalog', 'streams')
      end

      def call
        Services::Airbyte::ApiServer.post(
          path: '/api/v1/connections/update',
          access_token: @access_token,
          payload: connection_update_payload
        )
      end

      private

      def discovered_stream_for(stream_name)
        discovered_stream = @discovered_streams.find { |s| s.dig('stream', 'name') == stream_name.to_s } if @discovered_streams.present?

        return discovered_stream if discovered_stream.present?

        error_message = "Stream definition not found in discovered_schema for: #{stream_name}"
        Rails.logger.error(error_message)
        raise Error, error_message
      end

      def connection_update_payload
        {
          connectionId: @connection_id,
          syncCatalog: {
            streams: @allowed_list.map do |stream_name, fields|
              discovered_stream = discovered_stream_for(stream_name)
              {
                stream: {
                  name: stream_name.to_s,
                  namespace: discovered_stream.dig('stream', 'namespace'),
                  jsonSchema: discovered_stream.dig('stream', 'jsonSchema'),
                  supportedSyncModes: discovered_stream.dig('stream', 'supportedSyncModes'),
                  defaultCursorField: discovered_stream.dig('stream', 'defaultCursorField'),
                  sourceDefinedCursor: discovered_stream.dig('stream', 'sourceDefinedCursor'),
                  sourceDefinedPrimaryKey: discovered_stream.dig('stream', 'sourceDefinedPrimaryKey')
                },
                config: {
                  syncMode: SYNC_MODE,
                  destinationSyncMode: DESTINATION_SYNC_MODE,
                  cursorField: discovered_stream.dig('config', 'cursorField') || CURSOR_FIELD,
                  primaryKey: discovered_stream.dig('config', 'primaryKey') || [[DEFAULT_PRIMARY_KEY]],
                  aliasName: stream_name.to_s,
                  selected: true,
                  fieldSelectionEnabled: true,
                  selectedFields: (CURSOR_FIELD + AIRBYTE_FIELDS + fields).uniq.map { |f| { fieldPath: [f] } }
                }
              }
            end
          }
        }
      end
    end
  end
end
