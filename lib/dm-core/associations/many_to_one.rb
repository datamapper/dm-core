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
            @#{name} = #{name}_relationship.get_parent(self)
          end

          def #{name}=(parent)
            #{name}_relationship.attach_parent(self, parent)
            @#{name} = parent
          end

          private

          def #{name}_relationship
            model.relationships(#{repository_name.inspect})[#{name.inspect}]
          end
        EOS

        model.relationships(repository_name)[name] = Relationship.new(
          name,
          repository_name,
          model,
          options.fetch(:class_name, Extlib::Inflection.classify(name)),
          options
        )
      end
    end # module ManyToOne
  end # module Associations
end # module DataMapper
