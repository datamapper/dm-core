module DataMapper
  module Support
    module Symbol
      def gt
        DataMapper::Query::Operator.new(self, :gt)
      end
  
      def gte
        DataMapper::Query::Operator.new(self, :gte)
      end
  
      def lt
        DataMapper::Query::Operator.new(self, :lt)
      end
  
      def lte
        DataMapper::Query::Operator.new(self, :lte)
      end
  
      def not
        DataMapper::Query::Operator.new(self, :not)
      end
  
      def eql
        DataMapper::Query::Operator.new(self, :eql)
      end
  
      def like
        DataMapper::Query::Operator.new(self, :like)
      end
  
      def in
        DataMapper::Query::Operator.new(self, :in)
      end

      def to_proc
        lambda { |value| value.send(self) }
      end
      
      # Calculations:
  
      def count
        DataMapper::Query::Operator.new(self, :count)
      end
  
      def max
        DataMapper::Query::Operator.new(self, :max)
      end
  
      def avg
        DataMapper::Query::Operator.new(self, :avg)
      end
      
      alias average avg
  
      def min
        DataMapper::Query::Operator.new(self, :min)
      end
      
    end # module Symbol
  end # module Support
end # module DataMapper

class Symbol #:nodoc:
  include DataMapper::Support::Symbol
end