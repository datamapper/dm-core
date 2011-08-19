module DataMapper
  module Ext
    # Determines whether the specified +value+ is blank.
    #
    # An object is blank if it's false, empty, or a whitespace string.
    # For example, "", "   ", +nil+, [], and {} are blank.
    #
    # @api semipublic
    def self.blank?(value)
      return value.blank? if value.respond_to?(:blank?)
      case value
      when ::NilClass, ::FalseClass
        true
      when ::TrueClass, ::Numeric
        false
      when ::Array, ::Hash
        value.empty?
      when ::String
        value !~ /\S/
      else
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end
    end
  end
end
