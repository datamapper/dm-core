# TODO: make it so that a child_key is created with nullable => false if
#       @min == 1

module DataMapper
  module Associations
    module OneToOne
      class Relationship < DataMapper::Associations::Relationship
        private

        # TODO: document
        # @api semipublic
        def initialize(name, child_model, parent_model, options = {})
          child_model ||= Extlib::Inflection.camelize(name)
          options[:max] = 1
          super
        end

        # TODO: document
        # @api semipublic
        def create_helper
          return if parent_model.instance_methods(false).include?("#{name}_helper")
          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            private
            def #{name}_helper
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
        end

        # TODO: document
        # @api semipublic
        def create_accessor
          return if parent_model.instance_methods(false).include?(name)
          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            public  # TODO: make this configurable
            def #{name}
              #{name}_helper.first
            end
          EOS
        end

        # TODO: document
        # @api semipublic
        def create_mutator
          return if parent_model.instance_methods(false).include?("#{name}=")
          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            public  # TODO: make this configurable
            def #{name}=(child_resource)
              #{name}_helper.replace(child_resource.nil? ? [] : [ child_resource ])
            end
          EOS
        end
      end # class Relationship
    end # module HasOne
  end # module Associations
end # module DataMapper
