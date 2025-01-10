module DfE
  module Analytics
    class InstallGenerator < ::Rails::Generators::Base
      namespace 'dfe:analytics:install'

      def install
        create_file 'config/initializers/dfe_analytics.rb', <<~FILE
          ActiveSupport.on_load(:active_record) do
            include DfE::Analytics::TransactionChanges
          end
        FILE
      end
    end
  end
end
