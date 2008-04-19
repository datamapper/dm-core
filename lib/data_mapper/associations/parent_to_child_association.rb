require 'forwardable'

module DataMapper
  module Associations
    class ParentToChildAssociation
      extend Forwardable
      include Enumerable

      def_delegators :children, :[], :size, :length, :first, :last

      def each
        children.each { |child| yield(child) }
      end

      def children
        @children_resources ||= @children_loader.call
      end

      def save
        @dirty_children.each do |child_resource|
          @relationship.attach_parent(child_resource, @parent_resource)
          repository(@relationship.repository_name).save(child_resource)
        end
      end

      def push(*child_resources)
        child_resources.each do |child_resource|
          children << child_resource

          if @parent_resource.new_record?
            @dirty_children << child_resource
          else
            @relationship.attach_parent(child_resource, @parent_resource)
            repository(@relationship.repository_name).save(child_resource)
          end
        end
        self
      end

      alias << push

      def delete(child_resource)
        deleted_resource = children.delete(child_resource)
        begin
          @relationship.attach_parent(deleted_resource, nil)
          repository(@relationship.repository_name).save(deleted_resource)
        rescue
          children << child_resource
          raise
        end
      end

      private

      def initialize(relationship, parent_resource, &children_loader)
#        raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless Relationship === relationship
#        raise ArgumentError, "+parent_resource+ should be a DataMapper::Resource, but was #{parent_resource.class}", caller            unless Resource     === parent_resource

        @relationship    = relationship
        @parent_resource = parent_resource
        @children_loader = children_loader
        @dirty_children  = []
      end
    end # class ParentToChildAssociation
  end # module Associations
end # module DataMapper
