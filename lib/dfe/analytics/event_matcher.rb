module DfE
  module Analytics
    # Match event against given filters
    class EventMatcher
      attr_reader :event, :filters, :mask_hidden_data

      def initialize(event, filters = DfE::Analytics.event_debug_filters[:event_filters], mask_hidden_data: true)
        raise 'Event filters must be set' if filters.nil?

        @event = event.with_indifferent_access
        @filters = filters.compact
        @mask_hidden_data = mask_hidden_data

        mask_hidden_data! if mask_hidden_data
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

        regexp = Regexp.new(filter_value)

        regexp.match?(event_value)
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

      def mask_hidden_data!
        return unless mask_hidden_data && @event[:data] && @event[:entity_table_name]

        Rails.logger.info "Calling mask_hidden_data! for event: #{@event}"
        Rails.logger.debug "Calling mask_hidden_data! for event: #{@event}"

        @event[:data] = DfE::Analytics.mask_hidden_data(@event[:data], @event[:entity_table_name])
      end
    end
  end
end
