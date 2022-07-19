module DfE
  module Analytics
    # Tools to check and update configuration for model fields sent via
    # DfE::Analytics
    module Fields
      def self.blocklist
        DfE::Analytics.blocklist
      end

      def self.allowlist
        DfE::Analytics.allowlist
      end

      def self.generate_blocklist
        diff_model_attributes_against(allowlist)[:missing]
      end

      def self.unlisted_fields
        diff_model_attributes_against(allowlist, blocklist)[:missing]
      end

      def self.surplus_fields
        diff_model_attributes_against(allowlist)[:surplus]
      end

      def self.conflicting_fields
        allowlist.keys.reduce({}) do |conflicts, entity|
          intersection = Array.wrap(blocklist[entity]) & allowlist[entity]

          conflicts[entity] = intersection if intersection.any?

          conflicts
        end
      end

      def self.diff_model_attributes_against(*lists)
        DfE::Analytics.all_entities_in_application
          .reduce({ missing: {}, surplus: {} }) do |diff, entity|
            attributes_considered = lists.map do |list|
              # for each list of model attrs, look up the attrs for this model
              list.fetch(entity, [])
            end.reduce(:concat)

            model = DfE::Analytics.model_for_entity(entity)

            missing_attributes = model.attribute_names - attributes_considered
            surplus_attributes = attributes_considered - model.attribute_names

            diff[:missing][entity] = missing_attributes if missing_attributes.any?

            diff[:surplus][entity] = surplus_attributes if surplus_attributes.any?

            diff
          end
      end
    end
  end
end
