module DataMapper
  module Associations
    module ManyToMany
      private
      def many_to_many(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        # TOOD: raise an exception if unknown options are passed in

        child_model_name  = DataMapper::Inflection.demodulize(self.name)
        parent_model_name = options[:class_name] || DataMapper::Inflection.classify(name)

        relationships(repository.name)[name] = Relationship.new(
          name,
          options,
          repository.name,
          child_model_name,
          nil,
          parent_model_name,
          nil
        )        
        relationships(repository.name)[name]
      end

      # TODO: have this inherit from Collection (or LazyEnumerable)
      class Proxy
        def initialize() end

        def save
          raise NotImplementedError
        end

      end # class Proxy
    end # module ManyToMany
  end # module Associations
end # module DataMapper
