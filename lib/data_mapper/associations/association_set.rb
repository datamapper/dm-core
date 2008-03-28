module DataMapper
  module Associations
    class AssociationSet
      def initialize(relationship, &block)
        raise "The code to load the association must be supplied in a block" unless block_given?
        @relationship = relationship
        @loader = block
      end
      
      def relationship
        @relationship
      end
      
      def first
        entries.first
      end
      
      def each(&block)
        entries.each { |entry| yield entry }
      end
      
      def entries
        @entries = @loader[self]
        
        class << self
          def entries
            @entries
          end
        end
        
        @entries
      end
      
    end
  end
end