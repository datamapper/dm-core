module DataMapper
  module Associations
    module ManyToOne
      class Relationship < DataMapper::Associations::Relationship
        # TODO: document
        # @api semipublic
        def target_for(child_resource)
          values = child_key.get(child_resource)

          if values.any? { |v| v.blank? }
            return
          end

          repository = DataMapper.repository(parent_repository_name)
          conditions = query.merge(parent_key.zip(values).to_hash)

          Query.new(repository, parent_model, conditions)
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

                model.first(query)
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
              values = relationship.parent_key.get(parent) unless parent.nil?
              relationship.child_key.set(self, values)
              @#{name} = parent
            end
          RUBY
        end
      end # class Relationship
    end # module ManyToOne
  end # module Associations
end # module DataMapper
