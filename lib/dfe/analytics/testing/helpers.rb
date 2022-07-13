# frozen_string_literal: true

module DfE
  module Analytics
    module Testing
      module Helpers
        def stub_bigquery_auth!
          # will noop if called more than once
          @stub_bigquery_auth ||= begin
            DfE::Analytics.configure do |config|
              fake_bigquery_key = { 'type' => 'service_account',
                                    'project_id' => 'abc',
                                    'private_key_id' => 'abc',
                                    'private_key' => OpenSSL::PKey::RSA.new(2014).export,
                                    'client_email' => 'abc@example.com',
                                    'client_id' => '123',
                                    'auth_uri' => 'https://accounts.google.com/o/oauth2/auth',
                                    'token_uri' => 'https://oauth2.googleapis.com/token',
                                    'auth_provider_x509_cert_url' => 'https://www.googleapis.com/oauth2/v1/certs',
                                    'client_x509_cert_url' => 'https://www.googleapis.com/robot/v1/metadata/x509/abc' }

              config.bigquery_project_id = 'boom'
              config.bigquery_table_name = 'bang'
              config.bigquery_dataset = 'crash'
              config.bigquery_api_json_key = fake_bigquery_key.to_json
            end

            stub_request(:post, 'https://oauth2.googleapis.com/token')
              .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
          end
        end

        def stub_analytics_event_submission
          stub_bigquery_auth!

          stub_request(:post, /bigquery.googleapis.com/)
            .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
        end

        def stub_analytics_event_submission_with_insert_errors
          stub_bigquery_auth!

          body = {
            insertErrors: [
              {
                index: 0,
                errors: [
                  {
                    reason: 'error',
                    message: 'An error.'
                  }
                ]
              }
            ]
          }

          stub_request(:post, /bigquery.googleapis.com/)
            .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        def with_analytics_config(options)
          old_config = DfE::Analytics.config.dup
          DfE::Analytics.configure do |config|
            options.each { |option, value| config[option] = value }
          end

          yield
        ensure
          DfE::Analytics.instance_variable_set(:@config, old_config)
        end
      end
    end
  end
end
