require 'forwardable'

module DataMapper
  module Associations
    class AssociationSet
      extend Forwardable

      def_delegators :entries, :[], :size, :length

      def initialize(relationship, instance)
        @relationship = relationship
        @instance = instance
      end
      
      def relationship
        @relationship
      end
      
      def first
        entries.first
      end
      
      def entries
        @entries ||= @relationship.to_set(@instance)
      end

#      def size
#        entries.size
#      end

      def set(target)
        @relationship.source.each_with_index { |p, i| p.set(@relationship.target[i].value(target), @instance) }
      end
    end
  end
end
