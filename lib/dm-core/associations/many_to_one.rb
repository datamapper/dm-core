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

        if repository = options.delete(:repository)
          warn "+options[:repository]+ deprecated, specify :repository_name instead"
          options[:repository_name] = repository.name
        end

        child_repository_name = model.repository.name

        model.relationships(child_repository_name)[name] = Relationship.new(
          name,
          child_repository_name,
          options.delete(:repository_name) || child_repository_name,
          model,
          options.delete(:class_name) || Extlib::Inflection.camelize(name),
          options
        )
      end

      class Relationship < DataMapper::Associations::Relationship
        private

        def initialize(*)
          super
          @max = 1
        end

        def create_helper
          return if child_model.instance_methods(false).include?("#{name}_helper")
          child_model.class_eval <<-EOS, __FILE__, __LINE__
            private
            def #{name}_helper(query = nil)
              # TODO: when Resource can be matched against conditions
              # always set the ivar, but return the resource only if
              # it matches the conditions

              return @#{name} if query.nil? && defined?(@#{name})

              relationship = model.relationships(#{child_repository_name.inspect})[#{name.inspect}]

              values = relationship.child_key.get(self)

              resource = if values.any? { |v| v.blank? }
                nil
              else
                repository = DataMapper.repository(relationship.parent_repository_name)
                model      = relationship.parent_model
                conditions = relationship.query.merge(relationship.parent_key.zip(values).to_hash)

                if query
                  conditions.update(query)
                end

                query = Query.new(repository, model, conditions)

                model.first(query)
              end

              if query.nil?
                @#{name} = resource
              end

              resource
            end
          EOS
        end

        def create_accessor
          return if child_model.instance_methods(false).include?(name)
          child_model.class_eval <<-EOS, __FILE__, __LINE__
            public  # TODO: make this configurable

            # FIXME: if the accessor is used, caching nil in the ivar
            # and then the FK(s) are set, the cache in the accessor should
            # be cleared.

            def #{name}(query = nil)
              #{name}_helper(query)
            end
          EOS
        end

        def create_mutator
          return if child_model.instance_methods(false).include?("#{name}=")
          child_model.class_eval <<-EOS, __FILE__, __LINE__
            public  # TODO: make this configurable
            def #{name}=(parent)
              relationship = model.relationships(#{child_repository_name.inspect})[#{name.inspect}]
              values = relationship.parent_key.get(parent) unless parent.nil?
              relationship.child_key.set(self, values)
              @#{name} = parent
            end
          EOS
        end
      end # module Relationship
    end # module ManyToOne
  end # module Associations
end # module DataMapper
