# frozen_string_literal: true

module DfE
  module Analytics
    module Testing
      module Helpers
        def stub_analytics_event_submission
          if DfE::Analytics.config.azure_federated_auth
            nil
          else
            stub_analytics_legacy_event_submission
          end
        end

        def stub_bigquery_legacy_auth!
          # will noop if called more than once
          @stub_bigquery_legacy_auth ||= begin
            DfE::Analytics.configure do |config|
              fake_bigquery_key = { 'type' => 'service_account',
                                    'project_id' => 'abc',
                                    'private_key_id' => 'abc',
                                    'private_key' => OpenSSL::PKey::RSA.new(2048).export,
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

        def stub_analytics_legacy_event_submission
          stub_bigquery_legacy_auth!

          stub_request(:post, /bigquery.googleapis.com/)
            .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
        end

        def stub_analytics_event_submission_with_insert_errors
          if DfE::Analytics.config.azure_federated_auth
            nil
          else
            stub_analytics_legacy_event_submission_with_insert_errors
          end
        end

        def stub_analytics_legacy_event_submission_with_insert_errors
          stub_bigquery_legacy_auth!

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

        def stub_azure_access_token_request
          # will noop if called more than once
          @stub_azure_access_token_request ||= DfE::Analytics.configure do |config|
            config.azure_client_id = 'fake_az_client_id_1234'
            config.azure_scope = 'fake_az_scope'
            config.azure_token_path = 'fake_az_token_path'
            config.google_cloud_credentials = {
              credential_source: {
                url: 'https://login.microsoftonline.com/fake-az-token-id/oauth2/v2.0/token'
              }
            }
          end

          request_body = '{"grant_type":"client_credentials",' \
                         '"client_id":"fake_az_client_id_1234","scope":"fake_az_scope",' \
                         '"client_assertion_type":"urn:ietf:params:oauth:client-assertion-type:jwt-bearer",' \
                         '"client_assertion":"fake_az_token"}'

          response_body = {
            'token_type' => 'Bearer',
            'expires_in' => 86_399,
            'ext_expires_in' => 86_399,
            'access_token' => 'fake_az_response_token'
          }.to_json

          stub_request(:get, 'https://login.microsoftonline.com/fake-az-token-id/oauth2/v2.0/token')
            .with(
              body: request_body,
              headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
               'User-Agent' => 'Ruby'
              }
            )
             .to_return(
               status: 200,
               body: response_body,
               headers: {
                 'content-type' => ['application/json; charset=utf-8']
               }
             )
        end

        def stub_azure_access_token_request_with_auth_error
          # will noop if called more than once
          @stub_azure_access_token_request_with_auth_error ||= DfE::Analytics.configure do |config|
            config.azure_client_id = 'fake_az_client_id_1234'
            config.azure_scope = 'fake_az_scope'
            config.azure_token_path = 'fake_az_token_path'
            config.google_cloud_credentials = {
              credential_source: {
                url: 'https://login.microsoftonline.com/fake-az-token-id/oauth2/v2.0/token'
              }
            }
          end

          error_response_body = {
            'error' => 'unsupported_grant_type',
            'error_description' => 'AADSTS70003: The app requested an unsupported grant type ...',
            'error_codes' => [70_003],
            'timestamp' => '2024-03-18 19:55:40Z',
            'trace_id' => '0e58a943-a980-6d7e-89ba-c9740c572100',
            'correlation_id' => '84f1c2d2-5288-4879-a038-429c31193c9c'
          }.to_json

          stub_request(:get, 'https://login.microsoftonline.com/fake-az-token-id/oauth2/v2.0/token')
             .to_return(
               status: 400,
               body: error_response_body,
               headers: {
                 'content-type' => ['application/json; charset=utf-8']
               }
             )
        end

        def stub_azure_google_exchange_access_token_request
          # will noop if called more than once
          @stub_azure_google_exchange_access_token_request ||= DfE::Analytics.configure do |config|
            config.gcp_scope = 'fake_gcp_scope'
            config.azure_token_path = 'fake_az_token_path'
            config.google_cloud_credentials = {
              audience: 'fake_gcp_aud',
              subject_token_type: 'fake_sub_token_type',
              token_url: 'https://sts.googleapis.com/v1/token'
            }
          end

          request_body = '{"grant_type":"urn:ietf:params:oauth:grant-type:token-exchange",' \
                         '"audience":"fake_gcp_aud","scope":"fake_gcp_scope",' \
                         '"requested_token_type":"urn:ietf:params:oauth:token-type:access_token",' \
                         '"subject_token":"fake_az_response_token","subject_token_type":"fake_sub_token_type"}'

          response_body = {
            token_type: 'Bearer',
            expires_in: 3599,
            issued_token_type: 'urn:ietf:params:oauth:token-type:access_token',
            access_token: 'fake_az_gcp_exchange_token_response'
          }.to_json

          stub_request(:post, 'https://sts.googleapis.com/v1/token')
            .with(
              body: request_body,
              headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
               'User-Agent' => 'Ruby'
              }
            )
             .to_return(
               status: 200,
               body: response_body,
               headers: {
                 'content-type' => ['application/json; charset=utf-8']
               }
             )
        end

        def stub_azure_google_exchange_access_token_request_with_auth_error
          # will noop if called more than once
          @stub_azure_google_exchange_access_token_request_with_auth_error ||= DfE::Analytics.configure do |config|
            config.gcp_scope = 'fake_gcp_scope'
            config.azure_token_path = 'fake_az_token_path'
            config.google_cloud_credentials = {
              audience: 'fake_gcp_aud',
              subject_token_type: 'fake_sub_token_type',
              token_url: 'https://sts.googleapis.com/v1/token'
            }
          end

          error_response_body = {
            error: 'invalid_grant',
            error_description: 'Unable to parse the ID Token.'
          }.to_json

          stub_request(:post, 'https://sts.googleapis.com/v1/token')
             .to_return(
               status: 400,
               body: error_response_body,
               headers: {
                 'content-type' => ['application/json; charset=utf-8']
               }
             )
        end

        def stub_google_access_token_request
          # will noop if called more than once
          @stub_google_access_token_request ||= DfE::Analytics.configure do |config|
            config.gcp_scope = 'fake_gcp_scope'
            config.azure_token_path = 'fake_az_token_path'
            config.google_cloud_credentials = {
              service_account_impersonation_url: 'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/cip-gcp-spike@my_project.iam.gserviceaccount.com:generateAccessToken'
            }
          end

          request_body = '{"scope":"fake_gcp_scope"}'

          response_body = {
            expireTime: '2024-03-09T14:38:02Z',
            accessToken: 'fake_google_response_token'
          }.to_json

          stub_request(
            :post,
            'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/cip-gcp-spike@my_project.iam.gserviceaccount.com:generateAccessToken'
          ).with(
            body: request_body,
            headers: {
             'Accept' => '*/*',
             'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
             'User-Agent' => 'Ruby'
            }
          ).to_return(
            status: 200,
            body: response_body,
            headers: {
              'content-type' => ['application/json; charset=utf-8']
            }
          )
        end

        def stub_google_access_token_request_with_auth_error
          # will noop if called more than once
          @stub_google_access_token_request_with_auth_error ||= DfE::Analytics.configure do |config|
            config.gcp_scope = 'fake_gcp_scope'
            config.azure_token_path = 'fake_az_token_path'
            config.google_cloud_credentials = {
              service_account_impersonation_url: 'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/cip-gcp-spike@my_project.iam.gserviceaccount.com:generateAccessToken'
            }
          end

          error_response_body = {
            error: {
              code: 401,
              message: 'Request had invalid authentication credentials. Expected OAuth 2 access token, login cookie or other valid authentication credential. See https://developers.google.com/identity/sign-in/web/devconsole-project.',
              status: 'UNAUTHENTICATED',
              details: [{
                '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
                reason: 'ACCESS_TOKEN_TYPE_UNSUPPORTED',
                metadata: {
                  service: 'iamcredentials.googleapis.com',
                  method: 'google.iam.credentials.v1.IAMCredentials.GenerateAccessToken'
                }
              }]
            }
          }.to_json

          stub_request(
            :post,
            'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/cip-gcp-spike@my_project.iam.gserviceaccount.com:generateAccessToken'
          ).to_return(
            status: 401,
            body: error_response_body,
            headers: {
              'content-type' => ['application/json; charset=utf-8']
            }
          )
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

        def test_dummy_config
          config = DfE::Analytics.config.members.each_with_object({}) { |key, mem| mem[key] = 'dummy_value' }
          config[:google_cloud_credentials] = '{ "dummy_value":  1 }'
          config[:bigquery_api_json_key] = '{ "dummy_value":  1 }'
          config
        end
      end
    end
  end
end
