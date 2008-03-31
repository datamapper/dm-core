require __DIR__.parent + 'associations'
require __DIR__ + 'relationship'
require __DIR__ + 'parent_to_child_association'

module DataMapper
  module Associations
    module HasMany

      def has_many(name, options = {})
        self.send(:extend, Associations)

        source = (options[:class_name] || Inflector.classify(name))
        self_name = Inflector.demodulize(self.name)
        self.relationships[name] = Relationship.
            new(Inflector.underscore(self_name).to_sym, options[:repository_name] || self.repository.name, [source, nil], [self_name, nil])

        class_eval <<-EOS
          def #{name}
            #{name}_association
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              association = self.class.relationships[:#{name}].
                with_parent(self, ParentToChildAssociation) do |repository, child_rel, parent_rel, child_res, parent|
                  repository.all(child_res, child_rel.to_hash(parent_rel.value(parent)))
              end

              as_parent_associations << association

              association
            end
          end
        EOS
      end

    end # module HasMany
  end # module Associations
end # module DataMapper
