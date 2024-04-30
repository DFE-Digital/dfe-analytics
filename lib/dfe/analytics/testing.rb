# frozen_string_literal: true

module DfE
  module Analytics
    module Testing
      class << self
        def fake?
          @test_mode == :fake
        end

        def webmock?
          @test_mode == :webmock
        end

        def fake!(&block)
          switch_test_mode(:fake, &block)
        end

        def webmock!(&block)
          switch_test_mode(:webmock, &block)
        end

        private

        attr_accessor :test_mode

        def switch_test_mode(test_mode)
          raise('Invalid test mode for DfE::Analytics') unless %i[fake webmock].include? test_mode

          if block_given?
            begin
              old_test_mode = @test_mode
              @test_mode = test_mode
              yield
            ensure
              @test_mode = old_test_mode
            end
          else
            @test_mode = test_mode
          end
        end
      end
    end

    class LegacyStubClient
      Response = Struct.new(:success?)

      def insert(*)
        Response.new(true)
      end
    end

    module LegacyTestOverrides
      def events_client
        if DfE::Analytics::Testing.fake?
          LegacyStubClient.new
        else
          super
        end
      end
    end

    class StubClient
      Response = Struct.new(:insert_errors)

      def insert(*)
        Response.new([])
      end
    end

    module TestOverrides
      def events_client
        if DfE::Analytics::Testing.fake?
          StubClient.new
        else
          super
        end
      end
    end

    # Default to fake mode
    DfE::Analytics::Testing.fake!

    DfE::Analytics::BigQueryLegacyApi.singleton_class.send :prepend, LegacyTestOverrides
    DfE::Analytics::BigQueryApi.singleton_class.send :prepend, TestOverrides
  end
end
