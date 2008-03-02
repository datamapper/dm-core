require 'data_mapper/types/base'

module DataMapper
  module Types
    class String < ::String
      include Types::Base

      TYPE_MAP[:string] = self
      TYPE_MAP[::String] = self

      def self.length
        length_validator
      end

      def self.matches(regexp)
        match_validator.matches(regexp)
      end 

      def self.length_validator
        @length_validator ||
          @length_validator = Validations::NumberValidator.new
      end

      def self.match_validator
        @match_validator || @match_validator = Validations::StringValidator.new
      end

      def do_validations
        errors.concat(self.class.length_validator.errors_for(length))
        errors.concat(self.class.match_validator.errors_for(self))
      end
    end
  end
end
