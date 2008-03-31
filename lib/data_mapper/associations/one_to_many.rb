require 'forwardable'
require __DIR__.parent + 'associations'
require __DIR__ + 'relationship'
require __DIR__ + 'parent_to_child_association'

module DataMapper
  module Associations
    module OneToMany
      def one_to_many(name, options = {})
        self.send(:extend, Associations)

        source = (options[:class_name] || DataMapper::Inflection.classify(name))
        self_name = DataMapper::Inflection.demodulize(self.name)
        self.relationships[name] = Relationship.
          new(DataMapper::Inflection.underscore(self_name).to_sym, options[:repository_name] || self.repository.name, [source, nil], [self_name, nil])

        class_eval <<-EOS
          def #{name}
            #{name}_association
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              association = self.class.relationships[:#{name}].
                with_parent(self, Instance) do |repository, child_rel, parent_rel, child_res, parent|
                  repository.all(child_res, child_rel.to_hash(parent_rel.value(parent)))
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
      end
    end
  end # module Associations
end # module DataMapper
