# frozen_string_literal: true

module DfE
  module Analytics
    # Railtie
    class Railtie < Rails::Railtie
      initializer 'dfe.analytics.configure_params' do |app|
        i18n_files = File.expand_path("#{File.dirname(__FILE__)}/../../../config/locales/en.yml")
        I18n.load_path << i18n_files
        app.config.filter_parameters += [:hidden_data]
      end

      initializer 'dfe.analytics.insert_middleware' do |app|
        app.config.middleware.use DfE::Analytics::Middleware::RequestIdentity

        if ENV['RAILS_SERVE_STATIC_FILES'].present?
          app.config.middleware.insert_before \
            ActionDispatch::Static, DfE::Analytics::Middleware::SendCachedPageRequestEvent
        end
      end

      initializer 'dfe.analytics.logger' do
        ActiveSupport.on_load(:active_job) do
          analytics_job = DfE::Analytics::AnalyticsJob
          # Rails < 6.1 doesn't support log_arguments = false so we only log warn
          # to prevent wild log inflation
          if analytics_job.respond_to?(:log_arguments=)
            analytics_job.log_arguments = false
          else
            analytics_job.logger = ::Rails.logger.dup.tap { |l| l.level = Logger::WARN }
          end
        end
      end

      config.after_initialize do
        # internal gem tests will sometimes suppress this so they can test the
        # init process
        if running_db_rake_task? || ENV['SUPPRESS_DFE_ANALYTICS_INIT']
          puts 'Skipping DfE::Analytics initialization'
        else
          DfE::Analytics.initialize!
        end
      end

      def running_db_rake_task?
        defined?(Rake) && Rake.application.top_level_tasks.any? { |t| t.start_with?('db:') }
      end

      rake_tasks do
        path = File.expand_path(__dir__)
        Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
      end
    end
  end
end
