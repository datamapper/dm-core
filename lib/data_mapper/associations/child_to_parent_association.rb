module DataMapper
  module Associations
    class ChildToParentAssociation
      def initialize(relationship, child, parent_loader)
        @relationship, @child = relationship, child
        @parent_loader = parent_loader
      end

      def parent
        @parent ||= @parent_loader.call
      end

      def parent=(parent)
        @parent = parent

        @relationship.attach_parent(@child, @parent) if @parent.nil? || ! @parent.new_record?
      end

      def loaded?
        ! @parent.nil?
      end

      def save
        if @parent.new_record?
          repo = repository(@relationship.repository_name)
          repo.save(@parent)

          @relationship.attach_parent(@child, @parent)
        end
      end
    end
  end
end
