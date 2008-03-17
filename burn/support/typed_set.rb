require 'set'

module DataMapper
  module Support
    class TypedSet
      
      include ::Enumerable
      
      def initialize(*types)
        @types = types
        @set = SortedSet.new
      end
      
      def <<(item)
        raise ArgumentError.new("#{item.inspect} must be a kind of: #{@types.inspect}") unless @types.any? { |type| type === item }
        @set << item
        return self
      end
      
      def concat(values)
        [*values].each { |item| self << item }
        self
      end
      
      def inspect
        "#<DataMapper::Support::TypedSet#{@types.inspect}: {#{entries.inspect[1...-1]}}>"
      end
      
      def each
        @set.each { |item| yield(item) }
      end
      
      def delete?(item)
        @set.delete?(item)
      end
      
      def size
        @set.size
      end
      alias length size
      
      def empty?
        @set.empty?
      end
      alias blank? empty?
      
      def clear
        @set.clear
      end
      
      def +(other)
        x = self.class.new(*@types)
        each { |entry| x << entry }
        other.each { |entry| x << entry } unless other.blank?
        return x
      end
    end
  end
end

class Class
  
  include Comparable
  
  def <=>(other)
    name <=> other.name
  end
end