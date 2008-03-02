module DataMapper 
  module Validations 
    class Validator
      Error = Struct.new(:expected, :got)

      def errors_for(target)
        raise NotImplementedError.new
      end
    end
  end
end


