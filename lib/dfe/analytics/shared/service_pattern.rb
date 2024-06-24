module DfE
  module Analytics
    # a template for creating service objects
    module ServicePattern
      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          private_class_method(:new)
        end
      end

      def call
        raise(NotImplementedError('#call must be implemented'))
      end

      # provides class-level methods to the classes that include ServicePattern
      # defines a template for the `call` method; the expected entry point for service objects
      module ClassMethods
        def call(*args, **keyword_args, &block)
          return new.call if args.empty? && keyword_args.empty? && block.nil?

          new(*args, **keyword_args, &block).call
        end
      end
    end
  end
end
