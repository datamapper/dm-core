require __DIR__ + 'relationship'

module DataMapper
  module Associations
    module OneToOne

      def one_to_one(name, options = {})
        child = (options[:class_name] || DataMapper::Inflection.classify(name))
        self_name = DataMapper::Inflection.demodulize(self.name)

        self.relationships[name] = Relationship.new(
          DataMapper::Inflection.underscore(self_name).to_sym,
          options[:repository_name] || self.repository.name,
          [child, nil],
          [self_name, nil])

        class_eval <<-EOS
          def #{name}
            #{name}_association.first
          end

          def #{name}=(value)
            if #{name}_association.first != value
              #{name}_association.delete(#{name}_association.first)
              #{name}_association << value
            end
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              association = self.class.relationships[:#{name}].
                with_parent(self, Associations::OneToMany::Instance) do |repository, child_rel, parent_rel, child_res, parent|
                  repository.all(child_res, child_rel.to_hash(parent_rel.value(parent)))
                end

              parent_associations << association

              association
            end
          end
        EOS
      end

    end # module HasOne
  end # module Associations
end # module DataMapper
