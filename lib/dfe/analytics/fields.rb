module DfE
  module Analytics
    # Tools to check and update configuration for model fields sent via
    # DfE::Analytics
    module Fields
      def self.check!
        errors = []

        if surplus_fields.any?
          errors << <<~HEREDOC
            Database field removed! Please remove it from analytics.yml and then run

            bundle exec rails dfe:analytics:regenerate_blocklist

            Removed fields:

            #{surplus_fields.to_yaml}
          HEREDOC
        end

        if unlisted_fields.any?
          errors << <<~HEREDOC
            New database field detected! You need to decide whether or not to send it
            to BigQuery. To send, add it to config/analytics.yml. To ignore, run:

            bundle exec rails dfe:analytics:regenerate_blocklist

            New fields:

            #{unlisted_fields.to_yaml}
          HEREDOC
        end

        if conflicting_fields.any?
          errors << <<~HEREDOC
            Conflict detected between analytics.yml and analytics_blocklist.yml!

            The following fields exist in both files. To remove from the blocklist, run:

            bundle exec rails dfe:analytics:regenerate_blocklist

            Conflicting fields:

            #{conflicting_fields.to_yaml}
          HEREDOC
        end

        configuration_errors = errors.join("\n\n----------------\n\n")

        raise(ConfigurationError, configuration_errors) if errors.any?
      end

      def self.blocklist
        DfE::Analytics.blocklist
      end

      def self.allowlist
        DfE::Analytics.allowlist
      end

      def self.database
        DfE::Analytics.all_entities_in_application
          .reduce({}) do |list, entity|
            attrs = DfE::Analytics.model_for_entity(entity).attribute_names
            list[entity] = attrs

            list
          end
      end

      def self.generate_blocklist
        diff_between(database, allowlist)
      end

      def self.unlisted_fields
        diff_between(database, allowlist, blocklist)
      end

      def self.surplus_fields
        diff_between(allowlist, database)
      end

      def self.conflicting_fields
        diff_between(allowlist, diff_between(allowlist, blocklist))
      end

      # extract and concatenate the fields associated with an entity in 1 or
      # more entity->field lists
      def self.extract_entity_attributes_from_lists(entity, *lists)
        lists.map do |list|
          list.fetch(entity, [])
        end.reduce(:|)
      end

      # returns keys and values present in leftmost list and not present in any
      # of the other lists
      #
      # diff_between({a: [1, 2]}, {a: [2, 3]}) => {a: [1]}
      def self.diff_between(primary_list, *lists_to_compare)
        primary_list.reduce({}) do |diff, (entity, attrs_in_primary_list)|
          attrs_in_lists_to_compare = extract_entity_attributes_from_lists(entity, *lists_to_compare)
          differing_attrs = attrs_in_primary_list - attrs_in_lists_to_compare
          diff[entity] = differing_attrs if differing_attrs.any?

          diff
        end
      end
    end
  end
end
