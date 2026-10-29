# frozen_string_literal: true

require 'googleauth'

module DfE
  module Analytics
    # Google external account credentials using an Entra managed identity
    # access token as the subject token.
    class AzureFederatedAuth < Google::Auth::ExternalAccount::IdentityPoolCredentials
      DEFAULT_AZURE_SCOPE = 'api://AzureADTokenExchange/.default'
      DEFAULT_GCP_SCOPE   = 'https://www.googleapis.com/auth/cloud-platform'

      def self.gcp_client_credentials
        @gcp_client_credentials ||=
          new(
            {
              audience: DfE::Analytics.config.google_cloud_credentials[:audience],
              subject_token_type: DfE::Analytics.config.google_cloud_credentials[:subject_token_type],
              token_url: DfE::Analytics.config.google_cloud_credentials[:token_url],
              service_account_impersonation_url:
                DfE::Analytics.config.google_cloud_credentials[:service_account_impersonation_url],
              scope: DfE::Analytics.config.gcp_scope,
              credential_source: {
                url: DfE::Analytics.config.google_cloud_credentials[:credential_source][:url]
              }
            }
          )
      end

      def retrieve_subject_token!
        aad_token_request_body = {
          grant_type: 'client_credentials',
          client_id: DfE::Analytics.config.azure_client_id,
          scope: DfE::Analytics.config.azure_scope,
          client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
          client_assertion: File.read(DfE::Analytics.config.azure_token_path)
        }

        azure_token_response =
          HTTParty.post(
            DfE::Analytics.config.google_cloud_credentials[:credential_source][:url],
            headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
            body: URI.encode_www_form(aad_token_request_body)
          )

        unless azure_token_response.success?
          error_message = "Error calling azure token API: status: #{azure_token_response.code} body: #{azure_token_response.body}"

          Rails.logger.error error_message

          raise Error, error_message
        end

        azure_token_response.parsed_response['access_token']
      end

      class Error < StandardError; end
    end
  end
end
