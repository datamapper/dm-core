module DataMapper
  module Associations
    module ManyToMany
      extend Assertions

      # Setup many to many relationship between two models
      # -
      # @private
      def self.setup(name, model, options = {})
        assert_kind_of 'name',    name,    Symbol
        assert_kind_of 'model',   model,   Resource::ClassMethods
        assert_kind_of 'options', options, Hash

        raise NotImplementedError, 'many to many relationships not ready yet'

        repository_name = model.repository.name

        # TODO: add accessor/mutator to model with class_eval

        model.relationships(repository_name)[name] = Relationship.new(
          name,
          repository_name,
          model.name,
          options.fetch(:class_name, Extlib::Inflection.classify(name)),
          options
        )
      end

      class Proxy
        include Assertions

        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? respond_to? assert_kind_of should should_not ].include?(m) }

        def save
          raise NotImplementedError
        end

        def kind_of?(klass)
          # TODO: uncomment once proxy target method defined
          super # || child.kind_of?(klass)
        end

        def respond_to?(method, include_private = false)
          # TODO: uncomment once proxy target method defined
          super # || child.respond_to?(method)
        end

        private

        def initialize
          raise NotImplementedError
        end

      end # class Proxy
    end # module ManyToMany
  end # module Associations
end # module DataMapper
