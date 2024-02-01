# frozen_string_literal: true

module DfE
  module Analytics
    # Utility methods for query string processing
    module QueryStringUtilities
      def query_string_to_hash(query_string)
        hash = Rack::Utils.parse_query(query_string)
        hash = filter_query_string(hash) if DfE::Analytics.filter_web_request_events?
        hash
      end

      def filter_query_string(hash)
        DfE::Analytics.web_request_event_filter.filter(hash)
      end
    end
  end
end
