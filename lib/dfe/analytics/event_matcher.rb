module DfE
  module Analytics
    # Match event against given filters
    class EventMatcher
      attr_reader :event, :filters

      def initialize(event, filters = DfE::Analytics.event_debug_filters[:event_filters])
        raise 'Event filters must be set' if filters.nil?

        @event = event.with_indifferent_access
        @filters = filters.compact
      end

      def matched?
        filters.any? { |filter| filter_matched?(filter) }
      end

      private

      def filter_matched?(filter, nested_fields = [])
        filter.all? do |field, filter_value|
          fields = nested_fields + [field]

          if filter_value.is_a?(Hash)
            # Recurse for nested hashes
            filter_matched?(filter_value, fields)
          else
            field_matched?(filter_value, fields)
          end
        end
      end

      def field_matched?(filter_value, nested_fields)
        event_value = event_value_for(nested_fields)

        if event_value.nil? || filter_value.nil?
          Rails.logger.error("Nil value encountered. event_value: #{event_value.inspect}, filter_value: #{filter_value.inspect}, nested_fields: #{nested_fields.inspect}")
          return false
        end

        begin
          regexp = Regexp.new(filter_value)
          regexp.match?(event_value)
        rescue => e
          Rails.logger.error("Error in EventMatcher#field_matched?: #{e.message}. event_value: #{event_value.inspect}, filter_value: #{filter_value.inspect}, nested_fields: #{nested_fields.inspect}")
          false
        end
      end

      def event_value_for(nested_fields)
        nested_fields.reduce(event) do |memo, field|
          break memo.to_s unless memo.is_a?(Hash)

          memo[field]
        end.to_s
      end
    end
  end
end
