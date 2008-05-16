module DataMapper
  module Associations
    module ManyToMany
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max ]

      private

      def many_to_many(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        child_model_name  = DataMapper::Inflection.demodulize(self.name)
        parent_model_name = options.fetch(:class_name, DataMapper::Inflection.classify(name))

        relationship = relationships(repository.name)[name] = Relationship.new(
          name,
          repository.name,
          child_model_name,
          parent_model_name,
          options
        )

        # TODO: add accessor/mutator to model with class_eval

        relationships
      end

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
