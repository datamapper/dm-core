require 'forwardable'

module DataMapper
  module Associations
    class ParentToChildAssociation
      extend Forwardable

      def_delegators :children, :[], :size, :length, :first, :last

      def initialize(relationship, parent, loader)
        @relationship = relationship
        @loader = loader
        @parent = parent
        @dirty_children = []
      end

      def children
        @children ||= @loader.call
      end

      def save
        @dirty_children.each do |c|
          @relationship.attach_parent(c, @parent)
          repository(@relationship.repository_name).save(c)
        end
      end

      def <<(child)
        (@children ||= []) << child

        if @parent.new_record?
          @dirty_children << child
        else
          @relationship.attach_parent(child, @parent)
          repository(@relationship.repository_name).save(child)
        end

        self
      end

      def delete(child)
        deleted = children.delete(child)
        begin
          @relationship.attach_parent(deleted, nil)
          repository(@relationship.repository_name).save(deleted)
        rescue
          children.push(child)
          raise
        end
      end
    end # class ParentToChildAssociation
  end # module Associations
end # module DataMapper
