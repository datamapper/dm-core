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
            association_get(:#{name})
          end

          def #{name}=(parent)
            association_set(:#{name}, parent)
          end

          private

          # the 2 methods below should go into resource and should call 
          # associations[name].set(resource, association_value) (or something similar)
          def association_set(name, parent)
            r = model.relationships(#{repository_name.inspect})[name]
            parent_key = r.parent_key.get(parent) unless parent.nil?
            r.child_key.set(self, parent_key)
            instance_variable_set("@\#{name}", parent)
          end
          
          def association_get(name)
            r = model.relationships(#{repository_name.inspect})[name]
            instance_variable_get("@\#{name}") || 
              instance_variable_set("@\#{name}", r.get_parent(self))
            @#{name} ||= r.get_parent(self)
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
