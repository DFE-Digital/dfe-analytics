module DfE
  module Analytics
    module Middleware
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
