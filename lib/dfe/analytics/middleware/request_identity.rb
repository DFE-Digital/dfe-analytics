module DfE
  module Analytics
    module Middleware
      # Middleware to persist the Rails request UUID in memory where it can be
      # retrieved by all code running in the context of this request,
      # irrespective of whether that code has access to the original
      # ActionDispatch::Request object
      class RequestIdentity
        def initialize(app)
          @app = app
        end

        def call(env)
          RequestLocals.store[:dfe_analytics_request_id] = env.fetch('action_dispatch.request_id')
          @app.call(env)
        end
      end
    end
  end
end
