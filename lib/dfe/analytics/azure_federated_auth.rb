# frozen_string_literal: true

require 'googleauth'

module DfE
  module Analytics
    # Azure client for workload identity federation with GCP using OAuth
    class AzureFederatedAuth
      DEFAULT_AZURE_SCOPE = 'api://AzureADTokenExchange/.default'
      DEFAULT_GCP_SCOPE   = 'https://www.googleapis.com/auth/cloud-platform'
      ACCESS_TOKEN_EXPIRY_LEEWAY = 10.seconds

      def self.gcp_client_credentials
        return @gcp_client_credentials if @gcp_client_credentials && !@gcp_client_credentials.expired?

        azure_token = azure_access_token

        azure_google_exchange_token = azure_google_exchange_access_token(azure_token)

        google_token, expiry_time = google_access_token(azure_google_exchange_token)

        expiry_time_with_leeway = expiry_time - ACCESS_TOKEN_EXPIRY_LEEWAY

        @gcp_client_credentials = Google::Auth::UserRefreshCredentials.new(access_token: google_token, expires_at: expiry_time_with_leeway)
      end

      def self.azure_access_token
        aad_token_request_body = {
          grant_type: 'client_credentials',
          client_id: DfE::Analytics.config.azure_client_id,
          scope: DfE::Analytics.config.azure_scope,
          client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
          client_assertion: File.read(DfE::Analytics.config.azure_token_path)
        }

        azure_token_response =
          HTTParty.get(DfE::Analytics.config.google_cloud_credentials[:credential_source][:url], body: aad_token_request_body)

        unless azure_token_response.success?
          error_message = "Error calling azure token API: status: #{azure_token_response.code} body: #{azure_token_response.body}"

          Rails.logger.error error_message

          raise Error, error_message
        end

        azure_token_response.parsed_response['access_token']
      end

      def self.azure_google_exchange_access_token(azure_token)
        request_body = {
          grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
          audience: DfE::Analytics.config.google_cloud_credentials[:audience],
          scope: DfE::Analytics.config.gcp_scope,
          requested_token_type: 'urn:ietf:params:oauth:token-type:access_token',
          subject_token: azure_token,
          subject_token_type: DfE::Analytics.config.google_cloud_credentials[:subject_token_type]
        }

        exchange_token_response = HTTParty.post(DfE::Analytics.config.google_cloud_credentials[:token_url], body: request_body)

        unless exchange_token_response.success?
          error_message = "Error calling google exchange token API: status: #{exchange_token_response.code} body: #{exchange_token_response.body}"

          Rails.logger.error error_message

          raise Error, error_message
        end

        exchange_token_response.parsed_response['access_token']
      end

      def self.google_access_token(azure_google_exchange_token)
        google_token_response = HTTParty.post(
          DfE::Analytics.config.google_cloud_credentials[:service_account_impersonation_url],
          headers: { 'Authorization' => "Bearer #{azure_google_exchange_token}" },
          body: { scope:  DfE::Analytics.config.gcp_scope }
        )

        unless google_token_response.success?
          error_message = "Error calling google token API: status: #{google_token_response.code} body: #{google_token_response.body}"

          Rails.logger.error error_message

          raise Error, error_message
        end

        parsed_response = google_token_response.parsed_response

        [parsed_response['accessToken'], parsed_response['expiryTime']]
      end

      class Error < StandardError; end
    end
  end
end
