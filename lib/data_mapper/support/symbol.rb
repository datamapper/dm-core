module DataMapper
  module Support
    
    # Extends 
    module Symbol
      
      class Operator
      
        attr_reader :value, :type, :options
      
        def initialize(value, type, options = nil)
          @value, @type, @options = value, type, options
        end
    
        def to_sym
          @value
        end
      end
    
      def gt
        Operator.new(self, :gt)
      end
  
      def gte
        Operator.new(self, :gte)
      end
  
      def lt
        Operator.new(self, :lt)
      end
  
      def lte
        Operator.new(self, :lte)
      end
  
      def not
        Operator.new(self, :not)
      end
  
      def eql
        Operator.new(self, :eql)
      end
  
      def like
        Operator.new(self, :like)
      end
  
      def in
        Operator.new(self, :in)
      end

      def to_proc
        lambda { |value| value.send(self) }
      end
      
      # Calculations:
  
      def count
        Operator.new(self, :count)
      end
  
      def max
        Operator.new(self, :max)
      end
  
      def avg
        Operator.new(self, :avg)
      end
      
      alias average avg
  
      def min
        Operator.new(self, :min)
      end
      
    end # module Symbol
  end # module Support
end # module DataMapper

class Symbol #:nodoc:
  include DataMapper::Support::Symbol
end
