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

      def self.diff_model_attributes_against(*lists)
        Rails.application.eager_load!
        ActiveRecord::Base.descendants
          .reject { |model| model.name.include? 'ActiveRecord' } # ignore internal AR classes
          .reduce({ missing: {}, surplus: {} }) do |diff, next_model|
            table_name = next_model.table_name&.to_sym

            if table_name.present?
              attributes_considered = # then combine to get all the attrs we deal with
                lists.map do |list|
                  # for each list of model attrs, look up the attrs for this model
                  list.fetch(table_name, [])
                end.reduce(:concat)
              missing_attributes = next_model.attribute_names - attributes_considered
              surplus_attributes = attributes_considered - next_model.attribute_names

              diff[:missing][table_name] = missing_attributes if missing_attributes.any?

              diff[:surplus][table_name] = surplus_attributes if surplus_attributes.any?
            end

            diff
          end
      end
    end
  end
end
