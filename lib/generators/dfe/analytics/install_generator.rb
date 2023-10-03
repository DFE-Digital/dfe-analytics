module DfE
  module Analytics
    # require 'pry'
    class InstallGenerator < ::Rails::Generators::Base
      namespace 'dfe:analytics:install'

      def install
        create_file 'config/initializers/dfe_analytics.rb', <<~FILE
          DfE::Analytics.configure do |config|
          #{indent(config_options.map(&:strip).join("\n\n").gsub(/# $/, '#').chomp.chomp, 2)}
          end
        FILE

        create_file 'config/analytics.yml', { 'shared' => {} }.to_yaml
        create_file 'config/analytics_pii.yml', { 'shared' => {} }.to_yaml
        create_file 'config/analytics_blocklist.yml', { 'shared' => {} }.to_yaml
      end

      private

      def config_options
        DfE::Analytics.config.members.map do |option|
          <<~DESC
            # #{I18n.t("dfe.analytics.config.#{option}.description").lines.join('# ').chomp}
            #
            # config.#{option} = #{I18n.t("dfe.analytics.config.#{option}.default")}\n
          DESC
        end
      end
    end
  end
end
