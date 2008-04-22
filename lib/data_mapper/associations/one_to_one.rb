module DataMapper
  module Associations
    module OneToOne
    private
      def one_to_one(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        # TOOD: raise an exception if unknown options are passed in

        child_model_name  = options[:class_name] || DataMapper::Inflection.classify(name)
        parent_model_name = DataMapper::Inflection.demodulize(self.name)

        relationships[name] = Relationship.new(
          DataMapper::Inflection.underscore(parent_model_name).to_sym,
          options,
          repository.name,
          child_model_name,
          nil,
          parent_model_name,
          nil
        )

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association.first
          end

          def #{name}=(child_resource)
            #{name}_association.clear
            #{name}_association << child_resource unless child_resource.nil?
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              relationship = self.class.relationships[:#{name}]

              association = Associations::OneToMany::Proxy.new(relationship, self) do |repository, relationship|
                repository.all(*relationship.to_child_query(self))
              end

              parent_associations << association

              association
            end
          end
        EOS
        relationships[name]
      end

    end # module HasOne
  end # module Associations
end # module DataMapper
