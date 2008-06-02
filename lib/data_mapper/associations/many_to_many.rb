module DataMapper
  module Associations
    module ManyToMany

      # Setup many to many relationship between two models
      # -
      # @private
      def setup(name, model, options = {})
        raise NotImplementedError
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        repository_name = model.repository.name

        # TODO: add accessor/mutator to model with class_eval

        model.relationships(repository_name)[name] = Relationship.new(
          name,
          repository_name,
          model.name,
          options.fetch(:class_name, DataMapper::Inflection.classify(name)),
          options
        )
      end

      module_function :setup

      class Proxy
        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? should should_not ].include?(m) }

        def initialize() end

        def save
          raise NotImplementedError
        end

      end # class Proxy
    end # module ManyToMany
  end # module Associations
end # module DataMapper
