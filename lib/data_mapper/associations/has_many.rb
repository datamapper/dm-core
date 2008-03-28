require __DIR__.parent + 'associations'
require __DIR__ + 'relationship'

module DataMapper
  module Associations
    module HasMany

      def has_many(name, options = {})
        self.send(:extend, Associations)

        source = (options[:class_name] || Inflector.classify(name))
        self_name = Inflector.demodulize(self.name)
        self.relationships[name] = Relationship.
            new(name, self.repository.name, [source, [Inflector.foreign_key(self_name).to_sym]], [self_name, nil]) do |relationship, instance|

          keys = relationship.source.map { |p| p.name }
          values = relationship.target.map { |p| p.value(instance) }

          # everything inside all() should be the return value of a method in relationship, say #target_query or something
          instance.repository.all(relationship.source_resource, Hash[*keys.zip(values).flatten])
        end

        class_eval <<-EOS
          def #{name}
            #{name}_association
          end

          private
          def #{name}_association
            @#{name}_association || @#{name}_association = AssociationSet.new(self.class.relationships[:#{name}], self)
          end
        EOS
      end

    end # module HasMany
  end # module Associations
end # module DataMapper
