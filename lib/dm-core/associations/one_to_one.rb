module DataMapper
  module Associations
    module OneToOne
      extend Assertions

      # Setup one to one relationship between two models
      #
      # @api private
      def self.setup(name, model, options = {})
        assert_kind_of 'name',    name,    Symbol
        assert_kind_of 'model',   model,   Model
        assert_kind_of 'options', options, Hash

        parent_repository_name = model.repository.name

        model.class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association.first
          end

          def #{name}=(child_resource)
            #{name}_association.replace(child_resource.nil? ? [] : [ child_resource ])
          end

          private

          def #{name}_association
            @#{name} ||= begin
              # TODO: this seems like a bug.  the first time the association is
              # loaded it will be using the relationship object from the repo that
              # was in effect when it was defined.  Instead it should determine the
              # repo currently in-scope, and use the association for it.

              relationship = model.relationships(#{parent_repository_name.inspect})[#{name.inspect}]

              # TODO: do not build the query with child_key/parent_key.. use
              # child_accessor/parent_accessor.  The query should be able to
              # translate those to child_key/parent_key inside the adapter,
              # allowing adapters that don't join on PK/FK to work too.

              # FIXME: what if the parent key is not set yet, and the collection is
              # initialized below with the nil parent key in the query?  When you
              # save the parent and then reload the association, it will probably
              # not be found.  Test this.

              repository = DataMapper.repository(relationship.child_repository_name)
              model      = relationship.child_model
              conditions = relationship.query.merge(relationship.child_key.zip(relationship.parent_key.get(self)).to_hash)

              if relationship.max.kind_of?(Integer)
                conditions.update(:limit => relationship.max)
              end

              query = Query.new(repository, model, conditions)

              association = OneToMany::Collection.new(query)

              association.relationship = relationship
              association.parent       = self

              child_associations << association

              association
            end
          end
        EOS

        relationship = model.relationships(parent_repository_name)[name] = Relationship.new(
          name,
          options.key?(:repository) ? options.delete(:repository).name : parent_repository_name,
          parent_repository_name,
          options.delete(:class_name) || Extlib::Inflection.camelize(name),
          model,
          options
        )

        relationship
      end

      class Relationship < DataMapper::Associations::Relationship
        def max
          1
        end
      end # module Relationship
    end # module HasOne
  end # module Associations
end # module DataMapper
