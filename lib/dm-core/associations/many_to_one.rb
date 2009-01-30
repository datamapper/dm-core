module DataMapper
  module Associations
    module ManyToOne
      class Relationship < DataMapper::Associations::Relationship
        # TODO: document
        # @api semipublic
        def target_for(child_resource)
          # TODO: do not build the query with child_key/parent_key.. use
          # child_accessor/parent_accessor.  The query should be able to
          # translate those to child_key/parent_key inside the adapter,
          # allowing adapters that don't join on PK/FK to work too.

          child_repository_name  = child_resource.repository.name
          parent_repository_name = self.parent_repository_name || child_repository_name

          parent_key  = parent_key(parent_repository_name)
          child_value = child_key(child_repository_name).get(child_resource)

          if child_value.any? { |v| v.blank? }
            # child must have a valid reference to the parent
            return
          end

          query = self.query(child_repository_name).dup
          query.update(parent_key.zip(child_value).to_hash)

          Query.new(DataMapper.repository(parent_repository_name), parent_model, query)
        end

        private

        # TODO: document
        # @api semipublic
        def initialize(name, child_model, parent_model, options = {})
          parent_model ||= Extlib::Inflection.camelize(name)
          super
        end

        # TODO: document
        # @api semipublic
        def create_helper
          return if child_model.instance_methods(false).include?("#{name}_helper")

          child_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            private
            def #{name}_helper(conditions = nil)
              # TODO: when Resource can be matched against conditions
              # always set the ivar, but return the resource only if
              # it matches the conditions

              return @#{name} if conditions.nil? && defined?(@#{name})

              relationship = model.relationships(repository.name)[#{name.inspect}]

              resource = if query = relationship.target_for(self)
                if conditions
                  query.update(conditions)
                end

                query.model.first(query)
              else
                nil
              end

              return if resource.nil?

              @#{name} = resource
            end
          RUBY
        end

        # TODO: document
        # @api semipublic
        def create_accessor
          return if child_model.instance_methods(false).include?(name)

          child_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable

            # FIXME: if the accessor is used, caching nil in the ivar
            # and then the FK(s) are set, the cache in the accessor should
            # be cleared.

            def #{name}(query = nil)
              #{name}_helper(query)
            end
          RUBY
        end

        # TODO: document
        # @api semipublic
        def create_mutator
          return if child_model.instance_methods(false).include?("#{name}=")

          child_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{name}=(parent)
              relationship = model.relationships(repository.name)[#{name.inspect}]
              values = parent.nil? ? [] : relationship.parent_key(repository.name).get(parent)
              repository_name = relationship.child_repository_name || repository.name
              relationship.child_key(repository_name).set(self, values)
              @#{name} = parent
            end
          RUBY
        end

        # TODO: document
        # @api private
        def property_prefix
          name
        end
      end # class Relationship
    end # module ManyToOne
  end # module Associations
end # module DataMapper
