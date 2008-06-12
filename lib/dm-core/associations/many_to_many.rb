module DataMapper
  module Associations
    module ManyToMany

      # Setup many to many relationship between two models
      # -
      # @private
      def setup(name, model, options = {})
        raise NotImplementedError
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless name.kind_of?(Symbol)
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless options.kind_of?(Hash)

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

      module_function :setup

      class Proxy
        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? respond_to? should should_not ].include?(m) }

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
