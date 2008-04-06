require __DIR__ + 'relationship'

module DataMapper
  module Associations
    module OneToOne
      def one_to_one(name, options = {})
        child      = options[:class_name] || DataMapper::Inflection.classify(name)
        model_name = DataMapper::Inflection.demodulize(self.name)

        relationships[name] = Relationship.new(
          DataMapper::Inflection.underscore(model_name).to_sym,
          options[:repository_name] || repository.name,
          [ child,      nil ],
          [ model_name, nil ]
        )

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association.first
          end

          def #{name}=(value)
            if (original = #{name}_association.first) && original != value
              #{name}_association.delete(original)
            end
            #{name}_association << value
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              association = self.class.relationships[:#{name}].
                with_parent(self, Associations::OneToMany::Instance) do |repository, child_rel, parent_rel, child_res, parent|
                  repository.all(child_res, child_rel.to_query(parent_rel.get(parent)))
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
