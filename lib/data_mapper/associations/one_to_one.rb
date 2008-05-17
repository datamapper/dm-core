module DataMapper
  module Associations
    module OneToOne
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max ]

      private

      def one_to_one(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        child_model_name  = options.fetch(:class_name, DataMapper::Inflection.classify(name))
        parent_model_name = DataMapper::Inflection.demodulize(self.name)

        relationship = relationships(repository.name)[name] = Relationship.new(
          DataMapper::Inflection.underscore(parent_model_name).to_sym,
          repository.name,
          child_model_name,
          self.name,
          options
        )

        class_eval <<-EOS, __FILE__, __LINE__
          # FIXME: I think this is a subtle bug.  Since we return the resource directly
          # and not the proxy, then the proxy methods (like save) won't be fired off
          # as needed.  To fix this we may need a subclass of OneToMany that returns
          # a proxy object with just a single entry.
          def #{name}
            #{name}_association.first
          end

          def #{name}=(child_resource)
            #{name}_association.replace(child_resource.nil? ? [] : [ child_resource ])
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              relationship = self.class.relationships(repository.name)[:#{name}]
              association = Associations::OneToMany::Proxy.new(relationship, self)
              parent_associations << association
              association
            end
          end
        EOS

        relationship
      end

    end # module HasOne
  end # module Associations
end # module DataMapper
