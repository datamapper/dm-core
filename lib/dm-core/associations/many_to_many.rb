module DataMapper
  module Associations
    module ManyToMany
      class Relationship < DataMapper::Associations::Relationship
        def child_model
          @child_model ||= begin
            unless relationship = through.child_model.relationships(through.child_repository_name)[name]
              # TODO: raise a proper exception
              raise "#{name.inspect} can not be found through #{through.name.inspect} in #{parent_model}"
            end

            relationship.child_model
          end
        end

        def query
          query = super

          # TODO: figure out a way to make it so that Query uses multiple repositories

          #query[:links] ||= []

          # TODO: traverse each relationship, and append it onto query[:links]

          # TODO: merge in conditions for each association
          #   - make sure that each relationships' conditions are factored in,
          #     which will affect the final outcome.

          query
        end

        private

        def initialize(name, child_model, parent_model, options = {})
          through                = options[:through]
          parent_repository_name = options[:parent_repository_name]

          options[:through] = if through == Resource
            # TODO: create the join model if it does not already exist
            #   - if the child model and parent model are namespaced, then create the join table in the same namespace

            # TODO: create a one to many relationship to it from the parent model
            # TODO: create a many to one relationship from the join model to the parent model (necessary?)

            # TODO: set options[:through] to the relationship
            nil
          elsif through.kind_of?(Symbol)
            unless intermediary = parent_model.relationships(parent_repository_name)[through]
              raise ArgumentError, "through refers to an unknown relationship #{through} in repository #{parent_repository_name}"
            end

            intermediary
          end

          super
        end

        def create_helper
          # TODO: make sure the proper Query is set up, one that includes all the links
          #   - make sure that one to many and many to many can be intermediaries
          #   - make sure that each intermediary can be at random repositories
          #   - make sure that each intermediary can have different conditons that
          #     scope its results

          return if parent_model.instance_methods(false).include?("#{name}_helper")
          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            private
            def #{name}_helper
              @#{name} ||= begin
                # TODO: create a ManyToMany::Collection to represent the association
              end
            end
          EOS
        end

        # TODO: see if code can be shared with OneToMany::Relationship#create_accessor
        def create_accessor
          return if parent_model.instance_methods(false).include?(name)
          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            public  # TODO: make this configurable
            def #{name}(query = nil)
              #{name}_helper.all(query)
            end
          EOS
        end

        # TODO: see if code can be shared with OneToMany::Relationship#create_mutator
        def create_mutator
          return if parent_model.instance_methods(false).include?("#{name}=")
          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            public  # TODO: make this configurable
            def #{name}=(children)
              #{name}_helper.replace(children)
            end
          EOS
        end
      end # class Relationship

      class Collection < DataMapper::Collection
        # TODO: make sure all writers set the values in the intermediary Collections
      end # class Collection
    end # module ManyToMany
  end # module Associations
end # module DataMapper
