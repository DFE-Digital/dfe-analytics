# frozen_string_literal: true

module DfE
  module Analytics
    # Railtie
    class Railtie < Rails::Railtie
      config.before_initialize do
        i18n_files = File.expand_path("#{File.dirname(__FILE__)}/../../../config/locales/en.yml")
        I18n.load_path << i18n_files
      end

      initializer 'dfe.analytics.insert_middleware' do |app|
        app.config.middleware.use DfE::Analytics::Middleware::RequestIdentity
      end

      config.after_initialize do
        # internal gem tests will sometimes suppress this so they can test the
        # init process
        DfE::Analytics.initialize! unless ENV['SUPPRESS_DFE_ANALYTICS_INIT']
      end

      rake_tasks do
        path = File.expand_path(__dir__)
        Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
      end
    end
  end
end
