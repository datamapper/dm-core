require 'data_mapper/validations/validator'

module DataMapper 
  module Validations 
    class StringValidator < Validator
      def matches(regexp)
        @regexp = regexp
      end

      def errors_for(target)
        errors = []

        errors << Validator::Error.new(@regexp, target) if @regexp && !@regexp.match(target)

        errors
      end
    end
  end
end

