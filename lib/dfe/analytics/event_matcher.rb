module DfE
  module Analytics
    # Match event against given filters
    class EventMatcher
      attr_reader :event, :filters

      def initialize(event, filters = nil)
        filters ||= DfE::Analytics.event_debug_filters[:event_filters]

        @event = event.with_indifferent_access
        @filters = filters.compact
      end

      def matched?
        filters.any? { |filter| filter_matched?(filter) }
      end

      private

      def filter_matched?(filter, nested_fields = [])
        return false if filter.nil? || filter.values.any?(&:nil?)

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

        return false if event_value.nil?

        # Convert values to strings for comparison
        filter_value_str = filter_value.to_s
        event_value_str = event_value.to_s

        regexp = Regexp.new(filter_value_str)
        regexp.match?(event_value_str)
      end

      def event_value_for(nested_fields)
        # If nested hash fields in a filter don't correspond to hashes in the event THEN
        # - Convert the remaining value into a string (note: this maybe a whole array)
        # - Don't dig any deeper into the event on the first non hash value
        # - Will result in greedy and overzealous match as whole of nested structure compared
        nested_fields.reduce(event) do |memo, field|
          break memo.to_s unless memo.is_a?(Hash)

          memo[field]
        end
      end
    end
  end
end
