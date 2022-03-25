# frozen_string_literal: true

module DfE
  module Analytics
    class Railtie < Rails::Railtie
      config.before_initialize do
        i18n_files = File.expand_path("#{File.dirname(__FILE__)}/../../../config/locales/en.yml")
        I18n.load_path << i18n_files
      end

      initializer "dfe.analytics.insert_middleware" do |app|
        app.config.middleware.use DfE::Analytics::Middleware::RequestIdentity
      end

      rake_tasks do
        path = File.expand_path(__dir__)
        Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
      end
    end
  end
end
