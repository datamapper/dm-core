module DataMapper
  module Associations
    module ManyToOne
      extend Assertions

      # Setup many to one relationship between two models
      #
      # @api private
      def self.setup(name, model, options = {})
        assert_kind_of 'name',    name,    Symbol
        assert_kind_of 'model',   model,   Model
        assert_kind_of 'options', options, Hash

        repository_name = model.repository.name

        model.class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            return @#{name} if defined?(@#{name})

            relationship = #{name}_relationship

            values = relationship.child_key.get(self)

            @#{name} = if values.any? { |v| v.blank? }
              nil
            else
              repository = DataMapper.repository(relationship.repository_name)
              model      = relationship.parent_model
              conditions = relationship.query.merge(relationship.parent_key.zip(values).to_hash)

              query = Query.new(repository, model, conditions)

              model.first(query)
            end
          end

          def #{name}=(parent)
            relationship = #{name}_relationship
            values = relationship.parent_key.get(parent) unless parent.nil?
            relationship.child_key.set(self, values)
            @#{name} = parent
          end

          private

          def #{name}_relationship
            model.relationships(#{repository_name.inspect})[#{name.inspect}]
          end
        EOS

        relationship = model.relationships(repository_name)[name] = Relationship.new(
          name,
          repository_name,
          model,
          options[:class_name] || Extlib::Inflection.classify(name),
          options
        )

        # FIXME: temporary until the Relationship.new API is refactored to
        # accept type as the first argument, and RelationshipChain has been
        # removed
        relationship.type = self

        relationship
      end
    end # module ManyToOne
  end # module Associations
end # module DataMapper
