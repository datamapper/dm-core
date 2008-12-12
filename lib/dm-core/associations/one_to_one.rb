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

        repository_name = model.repository.name

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
              relationship = model.relationships(#{repository_name.inspect})[#{name.inspect}]
              association = Associations::OneToMany::Proxy.new(relationship, self)
              child_associations << association
              association
            end
          end
        EOS

        relationship = model.relationships(repository_name)[name] = Relationship.new(
          name,
          repository_name,
          options[:class_name] || Extlib::Inflection.classify(name),
          model,
          options
        )

        # FIXME: temporary until the Relationship.new API is refactored to
        # accept type as the first argument, and RelationshipChain has been
        # removed
        relationship.type = self

        relationship
      end
    end # module HasOne
  end # module Associations
end # module DataMapper
