module DataMapper
  module Ext
    def self.try_dup(value)
      case value
      when ::TrueClass, ::FalseClass, ::NilClass, ::Module, ::Numeric, ::Symbol
        value
      else
        value.dup
      end
    end
  end
end
