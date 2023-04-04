module DfE
  module Analytics
    module Middleware
      # Middleware to send request event to BigQuery if page cached by rack
      # In Rails a cached page is commonly served by ActionDispatch:Static middleware
      # This middleware must be inserted before ActionDispatch:Static to intercept request
      class SendCachedPageRequestEvent
        def initialize(app)
          @app = app
        end

        def call(env)
          # Detect if page is Cached and send request event accordingly
          send_request_event(env) if DfE::Analytics.rack_page_cached?(env)

          @app.call(env)
        end

        private

        def send_request_event(env)
          request = ActionDispatch::Request.new(env)

          request_event = DfE::Analytics::Event.new
                                               .with_type('web_request')
                                               .with_request_details(request)
                                               .with_response_details(response)
                                               .with_request_uuid(request.request_id)

          DfE::Analytics::SendEvents.do([request_event.as_json])
        end

        def response
          ActionDispatch::Response.new(304, 'Content-Type' => 'text/html; charset=utf-8')
        end
      end
    end
  end
end
