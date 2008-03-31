#require __DIR__.parent + 'support/class'
require __DIR__.parent + 'associations'
require __DIR__ + 'relationship'
require __DIR__ + 'child_to_parent_association'

module DataMapper
  module Associations
    module BelongsTo
      def belongs_to(name, options = {})
        self.send(:extend, DataMapper::Associations)

        target = (options[:class_name] || Inflector.camelize(name))

        self.relationships[name] = Relationship.
          new(name, options[:repository_name] || self.repository.name, [Inflector.demodulize(self.name), nil], [target, nil])

        class_eval <<-EOS
          def #{name}
            #{name}_association.parent
          end

          def #{name}=(value)
            #{name}_association.parent = value
          end

          private

          def #{name}_association
            @#{name}_association || @#{name}_association = begin
              association = self.class.relationships[:#{name}].
                  with_child(self, ChildToParentAssociation) do |repository, child_rel, parent_rel, parent_res, child|
                    repository.first(parent_res, parent_rel.to_hash(child_rel.value(child)))
              end

              as_child_associations << association

              association
            end
          end
        EOS
      end
    end # module BelongsTo
  end # module Associations
end # module DataMapper
