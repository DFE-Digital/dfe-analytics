module DfE
  module Analytics
    # Match event against given filters
    class EventMatcher
      attr_reader :event, :filters

      def initialize(event, filters = nil)
        filters ||= DfE::Analytics.event_debug_filters[:event_filters]
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
            if filter_value.nil?
              Rails.logger.error("Nil filter value encountered. filter_value: #{filter_value.inspect}, nested_fields: #{fields.inspect}")
              return false
            end
            field_matched?(filter_value, fields)
          end
        end
      end

      def field_matched?(filter_value, nested_fields)
        event_value = event_value_for(nested_fields)

        if event_value.nil?
          Rails.logger.error("Nil event value encountered. event_value: #{event_value.inspect}, nested_fields: #{nested_fields.inspect}")
          return false
        end

        # Log the original values before converting to strings
        Rails.logger.debug("Original filter_value: #{filter_value.inspect}, Original event_value: #{event_value.inspect}")

        # Convert values to strings for comparison
        filter_value_str = filter_value.to_s
        event_value_str = event_value.to_s

        begin
          regexp = Regexp.new(filter_value_str)
          regexp.match?(event_value_str)
        rescue StandardError => e
          Rails.logger.error("Error in EventMatcher#field_matched?: #{e.message}. original event_value: #{event_value.inspect}, original filter_value: #{filter_value.inspect}, nested_fields: #{nested_fields.inspect}")
          false
        end
      end

      def event_value_for(nested_fields)
        nested_fields.reduce(event) do |memo, field|
          break memo.to_s unless memo.is_a?(Hash)

          memo[field]
        end
      end
    end
  end
end
