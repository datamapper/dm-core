module DataMapper
  module Associations
    module ManyToOne

      # Setup many to one relationship between two models
      # -
      # @private
      def setup(name, model, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless name.kind_of?(Symbol)
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless options.kind_of?(Hash)

        repository_name = model.repository.name

        model.class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association.nil? ? nil : #{name}_association
          end

          def #{name}=(parent_resource)
            #{name}_association.replace(parent_resource)
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              relationship = model.relationships(#{repository_name.inspect})[:#{name}]
              association = Proxy.new(relationship, self)
              child_associations << association
              association
            end
          end
        EOS

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

        def replace(parent_resource)
          @parent_resource = parent_resource
          @relationship.attach_parent(@child_resource, @parent_resource) if @parent_resource.nil? || !@parent_resource.new_record?
          self
        end

        def save
          return unless parent && parent.new_record?

          repository(@relationship.repository_name) do
            parent.save
            @relationship.attach_parent(@child_resource, parent)
          end
        end

        def reload!
          @parent_resource = nil
          self
        end

        def kind_of?(klass)
          super || parent.kind_of?(klass)
        end

        def respond_to?(method, include_private = false)
          super || parent.respond_to?(method)
        end

        private

        def initialize(relationship, child_resource)
          raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless relationship.kind_of?(Relationship)
          raise ArgumentError, "+child_resource+ should be a DataMapper::Resource, but was #{child_resource.class}", caller              unless child_resource.kind_of?(Resource)

          @relationship   = relationship
          @child_resource = child_resource
        end

        def parent
          @parent_resource ||= @relationship.get_parent(@child_resource)
        end

        def kind_of?(klass)
           super || parent.kind_of?(klass)
        end

        def method_missing(method, *args, &block)
          parent.__send__(method, *args, &block)
        end
      end # class Proxy
    end # module ManyToOne
  end # module Associations
end # module DataMapper
