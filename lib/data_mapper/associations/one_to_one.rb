require __DIR__ + 'relationship'

module DataMapper
  module Associations
    module OneToOne
      def one_to_one(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        child_model_name  = options[:class_name] || DataMapper::Inflection.classify(name)
        parent_model_name = DataMapper::Inflection.demodulize(self.name)

        relationships[name] = Relationship.new(
          DataMapper::Inflection.underscore(parent_model_name).to_sym,
          options[:repository_name] || repository.name,
          child_model_name,
          nil,
          parent_model_name,
          nil
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
              relationship = self.class.relationships[:#{name}]

              association = relationship.with_parent(self, Associations::ParentToChildAssociation) do |repository, child_key, parent_key, child_model, parent_resource|
                repository.all(child_model, child_key.to_query(parent_key.get(parent_resource)))
              end

              parent_associations << association

              association
            end
          end
        EOS

        relationships[name]
      end

    end # module HasOne
  end # module Associations
end # module DataMapper
