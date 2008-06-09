module DataMapper
  module Associations
    module OneToOne

      # Setup one to one relationship between two models
      # -
      # @private
      def setup(name, model, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless name.kind_of?(Symbol)
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless options.kind_of?(Hash)

        repository_name = model.repository.name

        model.class_eval <<-EOS, __FILE__, __LINE__
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
            relationship = self.class.relationships(#{repository_name.inspect})[:#{name}]
              association = Associations::OneToMany::Proxy.new(relationship, self)
              parent_associations << association
              association
            end
          end
        EOS

        model.relationships(repository_name)[name] = if options.has_key?(:through)
          RelationshipChain.new(
            :child_model_name         => options.fetch(:class_name, Extlib::Inflection.classify(name)),
            :parent_model_name        => model.name,
            :repository_name          => repository_name,
            :near_relationship_name   => options[:through],
            :remote_relationship_name => options.fetch(:remote_name, name),
            :parent_key               => options[:parent_key],
            :child_key                => options[:child_key]
          )
        else
          Relationship.new(
            Extlib::Inflection.underscore(Extlib::Inflection.demodulize(model.name)).to_sym,
            repository_name,
            options.fetch(:class_name, Extlib::Inflection.classify(name)),
            model.name,
            options
          )
        end
      end

      module_function :setup

    end # module HasOne
  end # module Associations
end # module DataMapper
