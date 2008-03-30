#require __DIR__.parent + 'support/class'
require __DIR__.parent + 'associations'
require __DIR__ + 'relationship'

module DataMapper
  module Associations

    module BelongsTo
      extend Associations

      def belongs_to(name, options = {})
        self.send(:extend, Associations)

        target = (options[:class_name] || DataMapper::Inflection.camelize(name))

        self.relationships[name] = Relationship.
            new(name, self.repository.name, [DataMapper::Inflection.demodulize(self.name), nil], [target, nil]) do |relationship, instance|

          values = relationship.source.map { |p| p.value(instance) }

          # everything inside all() should be the return value of a method in relationship, say #target_query or something
          instance.repository.all(relationship.target_resource, Hash[*relationship.target.zip(values).flatten])
        end

        class_eval <<-EOS
          def #{name}
            #{name}_association.first
          end

          def #{name}=(value)
            #{name}_association.set(value)
          end

          private
          def #{name}_association
            @#{name}_association || @#{name}_association = AssociationSet.new(self.class.relationships[:#{name}], self)
          end
        EOS
      end
    end # module BelongsTo
  end # module Associations
end # module DataMapper
