module DataMapper
  module Associations
    module ManyToOne
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max ]

      private

      def many_to_one(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        parent_model_name = options[:class_name] || DataMapper::Inflection.classify(name)

        relationship = relationships(repository.name)[name] = Relationship.new(
          name,
          repository.name,
          self.name,
          parent_model_name,
          options
        )

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association.nil? ? nil : #{name}_association
          end

          def #{name}=(parent_resource)
            #{name}_association.replace(parent_resource)
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              relationship = self.class.relationships(#{repository.name.inspect})[:#{name}]
              association = Proxy.new(relationship, self)
              child_associations << association
              association
            end
          end
        EOS

        relationship
      end

      class Proxy
        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? should should_not ].include?(m) }

        def replace(parent_resource)
          @parent_resource = parent_resource
          @relationship.attach_parent(@child_resource, @parent_resource) if @parent_resource.nil? || !@parent_resource.new_record?
        end

        def save
          if parent && parent.new_record?
            repository(@relationship.repository_name) do
              parent.save
              @relationship.attach_parent(@child_resource, parent)
            end
          end
        end

        def reload!
          @parent_resource = nil
          self
        end

        private

        def initialize(relationship, child_resource)
#          raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless Relationship === relationship
#          raise ArgumentError, "+child_resource+ should be a DataMapper::Resource, but was #{child_resource.class}", caller              unless Resource     === child_resource

          @relationship   = relationship
          @child_resource = child_resource
        end

        def parent
          @parent_resource ||= @relationship.get_parent(@child_resource)
        end

        def method_missing(method, *args, &block)
          parent.__send__(method, *args, &block)
        end
      end # class Proxy
    end # module ManyToOne
  end # module Associations
end # module DataMapper
