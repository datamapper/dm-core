require 'data_mapper/validations/validator'

module DataMapper 
  module Validations 
    class NumberValidator < Validator
      def <(max)
        @max_excl = max
      end

      def <=(max)
        @max_incl = max
      end

      def >(min)
        @min_excl = min
      end

      def >=(min)
        @min_incl = min
      end

      def between(range)
        @range = range
      end

      def errors_for(target)
        errors = []
        error = nil

        errors << Validator::Error.new(@max_excl, target) if @max_excl && target >= @max_excl
        errors << Validator::Error.new(@max_incl, target) if @max_incl && target > @max_incl
        errors << Validator::Error.new(@min_excl, target) if @min_excl && target <= @min_excl
        errors << Validator::Error.new(@min_incl, target) if @min_incl && target < @min_incl
        errors << Validator::Error.new(@range, target) if @range && ! @range.include?(target)

        errors
      end
    end
  end
end
