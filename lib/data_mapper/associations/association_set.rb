require 'forwardable'

module DataMapper
  module Associations
    class AssociationSet
      extend Forwardable

      def_delegators :entries, :[], :size, :length, :first, :last

      def initialize(relationship, instance)
        @relationship = relationship
        @instance = instance
      end
      
      def entries
        @entries ||= @relationship.to_set(@instance)
      end

      def set(target)
        @relationship.source.each_with_index { |p, i| p.set(@relationship.target[i].value(target), @instance) }
      end
    end
  end
end
