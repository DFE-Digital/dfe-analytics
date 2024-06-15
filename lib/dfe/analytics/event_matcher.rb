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
        return false if event.nil? || filters.nil?

        filters.any? { |filter| filter_matched?(filter) }
      rescue StandardError => e
        Rails.logger.error("EventMatcher matched? error: #{e.message}")
        raise
      end

      private

      def filter_matched?(filter, nested_fields = [])
        return false if filter.nil?

        filter.all? do |field, filter_value|
          fields = nested_fields + [field]

          if filter_value.is_a?(Hash)
            # Recurse for nested hashes
            filter_matched?(filter_value, fields)
          else
            field_matched?(filter_value, fields)
          end
        rescue StandardError => e
          Rails.logger.error("EventMatcher filter_matched? error: #{e.message}")
          raise
        end
      end

      def field_matched?(filter_value, nested_fields)
        return false if filter_value.nil?

        event_value = event_value_for(nested_fields)

        return false if event_value.nil?

        event_value = 'HIDDEN' if nested_fields.include?('hidden_data')

        regexp = Regexp.new(filter_value)
        regexp.match?(event_value)
      rescue StandardError => e
        Rails.logger.error("EventMatcher field_matched? error: #{e.message}")
        raise
      end

      def event_value_for(nested_fields)
        # If nested hash fields in a filter don't correspond to hashes in the event THEN
        # - Convert the remaining value into a string (note: this maybe a whole array)
        # - Don't dig any deeper into the event on the first non hash value
        # - Will result in greedy and overzealous match as whole of nested structure compared
        nested_fields.reduce(event) do |memo, field|
          break memo.to_s unless memo.is_a?(Hash)

          value = memo[field]
          break '' if value.nil?

          value
        rescue StandardError => e
          Rails.logger.error("EventMatcher event_value_for error: #{e.message}")
          raise
        end
      end
    end
  end
end
