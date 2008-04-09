require 'forwardable'
require __DIR__.parent + 'associations'
require __DIR__ + 'relationship'
require __DIR__ + 'parent_to_child_association'

module DataMapper
  module Associations
    module OneToMany
      def one_to_many(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        source     = options[:class_name] || DataMapper::Inflection.classify(name)
        model_name = DataMapper::Inflection.demodulize(self.name)

        relationships[name] = Relationship.new(
          DataMapper::Inflection.underscore(model_name).to_sym,
          options[:repository_name] || repository.name,
          source,
          nil,
          model_name,
          nil
        )

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              association = self.class.relationships[:#{name}].
                with_parent(self, Instance) do |repository, child_rel, parent_rel, child_res, parent|
                  repository.all(child_res, child_rel.to_query(parent_rel.get(parent)))
                end

              parent_associations << association

              association
            end
          end
        EOS
      end

      class Instance
        extend Forwardable

        def_delegators :children, :[], :size, :length, :first, :last

        def initialize(relationship, parent_resource, &children_loader)
#          raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless Relationship === relationship
#          raise ArgumentError, "+parent_resource+ should be a DataMapper::Resource, but was #{parent_resource.class}", caller            unless Resource     === parent_resource

          @relationship    = relationship
          @parent_resource = parent_resource
          @children_loader = children_loader
          @dirty_children  = []
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

        def <<(child_resource)
          children << child_resource

          if @parent_resource.new_record?
            @dirty_children << child_resource
          else
            @relationship.attach_parent(child_resource, @parent_resource)
            repository(@relationship.repository_name).save(child_resource)
          end

          self
        end

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
      end # class Instance
    end # module OneToMany
  end # module Associations
end # module DataMapper
