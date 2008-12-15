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

        child_repository_name = model.repository.name

        model.class_eval <<-EOS, __FILE__, __LINE__

          # FIXME: if the accessor is used, caching nil in the ivar
          # and then the FK(s) are set, the cache in the accessor should
          # be cleared.

          def #{name}
            return @#{name} if defined?(@#{name})

            relationship = #{name}_relationship

            values = relationship.child_key.get(self)

            @#{name} = if values.any? { |v| v.blank? }
              nil
            else
              repository = DataMapper.repository(relationship.parent_repository_name)
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
            model.relationships(#{child_repository_name.inspect})[#{name.inspect}]
          end
        EOS

        relationship = model.relationships(child_repository_name)[name] = Relationship.new(
          name,
          child_repository_name,
          options.key?(:repository) ? options.delete(:repository).name : child_repository_name,
          model,
          options.delete(:class_name) || Extlib::Inflection.camelize(name),
          options
        )

        relationship
      end

      class Relationship < DataMapper::Associations::Relationship
        def max
          1
        end
      end # module Relationship
    end # module ManyToOne
  end # module Associations
end # module DataMapper
