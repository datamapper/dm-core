module DataMapper
  module Associations
    module OneToOne
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max, :remote_name ]

      private

      def one_to_one(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        relationship =
          relationships(repository.name)[name] =
          if options.include?(:through)
            RelationshipChain.new(:child_model_name => options.fetch(:class_name, DataMapper::Inflection.classify(name)),
                                  :parent_model_name => self.name,
                                  :repository_name => repository.name,
                                  :near_relationship_name => options[:through],
                                  :remote_relationship_name => options.fetch(:remote_name, name),
                                  :parent_key => options[:parent_key],
                                  :child_key => options[:child_key])
          else
            # TODO: raise a warning if the other side of the relationship
            # also has a one_to_one association
            Relationship.new(
              DataMapper::Inflection.underscore(DataMapper::Inflection.demodulize(self.name)).to_sym,
              repository.name,
              options.fetch(:class_name, DataMapper::Inflection.classify(name)),
              self.name,
              options
            )
          end

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
            relationship = self.class.relationships(#{repository.name.inspect})[:#{name}]
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
