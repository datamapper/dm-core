module DataMapper
  module Associations
    class AssociationSet
      def initialize(relationship, instance)
        raise "The code to load the association must be supplied in a block" unless block_given?
        @relationship = relationship
        @instance = instance
      end
      
      def relationship
        @relationship
      end
      
      def first
        @entries.first
      end
      
      def each
        @entries.each { |entry| yield entry }
      end
      
      def entries
        @entries
      end
      
    end
  end
end