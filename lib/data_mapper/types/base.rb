require 'data_mapper/validations/number_validator'
require 'data_mapper/validations/string_validator'

module DataMapper
  module Types
    TYPE_MAP = {}

    module Base
      module ClassMethods
        def context(ctx)
          contexts(ctx)
        end

        def contexts(*ctxs)
          @contexts || @contexts = %w{__all__} << ctxs.map { |c| c.to_s }
        end
      end

      def self.included(klass)
        klass.extend(ClassMethods)
      end

      def do_validations
        raise NotImplementedError.new
      end

      def valid?(context = "__all__")
        @errors = []

        if self.class.contexts.include?(context.to_s) 
          do_validations

          @errors.empty?
        else 
          true
        end
      end

      def errors
        @errors || @errors = []
      end
    end
  end
end
