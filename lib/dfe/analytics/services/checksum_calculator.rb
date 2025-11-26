# frozen_string_literal: true

module DfE
  module Analytics
    module Services
      # Delegates the checksum calculation to either a postgres or a generic checksum calculator
      class ChecksumCalculator
        include ServicePattern

        def initialize(entity, order_column, checksum_calculated_at)
          @entity = entity
          @order_column = order_column
          @checksum_calculated_at = checksum_calculated_at
          @adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
        end

        def call
          checksum_calculator
        end

        private

        attr_reader :entity, :order_column, :checksum_calculated_at, :adapter_name

        def checksum_calculator
          if postgres?
            DfE::Analytics::Services::PostgresChecksumCalculator.call(entity, order_column, checksum_calculated_at)
          else
            DfE::Analytics::Services::GenericChecksumCalculator.call(entity, order_column, checksum_calculated_at)
          end
        end

        def postgres?
          %w[postgresql postgis].include?(adapter_name)
        end
      end
    end
  end
end
