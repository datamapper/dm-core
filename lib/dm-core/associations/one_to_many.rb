require 'forwardable'

module DataMapper
  module Associations
    module OneToMany

      # Setup one to many relationship between two models
      # -
      # @private
      def setup(name, model, options = {})
        raise ArgumentError, "+name+ should be a Symbol (or Hash for +through+ support), but was #{name.class}", caller unless name.kind_of?(Symbol) || name.kind_of?(Hash)
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller                             unless options.kind_of?(Hash)

        repository_name = model.repository.name

        model.class_eval <<-EOS, __FILE__, __LINE__
          def #{name}(query = {})
            #{name}_association.all(query)
          end

          def #{name}=(children)
            #{name}_association.replace(children)
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              relationship = model.relationships(#{repository_name.inspect})[#{name.inspect}]
              raise ArgumentError.new("Relationship #{name.inspect} does not exist") unless relationship
              association = Proxy.new(relationship, self)
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

      # TODO: look at making this inherit from Collection.  The API is
      # almost identical, and it would make more sense for the
      # relationship.get_children method to return a Proxy than a
      # Collection that is wrapped in a Proxy.
      class Proxy
        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? respond_to? should should_not ].include?(m) }

        # FIXME: remove when RelationshipChain#get_children can return a Collection
        def all(query = {})
          query.empty? ? self : @relationship.get_children(@parent, query)
        end

        # FIXME: remove when RelationshipChain#get_children can return a Collection
        def first(*args)
          if args.last.respond_to?(:merge)
            query = args.pop
            @relationship.get_children(@parent, query, :first, *args)
          else
            super
          end
        end

        def <<(resource)
          assert_mutable
          super
          relate_resource(resource)
          self
        end

        def push(*resources)
          assert_mutable
          super
          resources.each { |resource| relate_resource(resource) }
          self
        end

        def unshift(*resources)
          assert_mutable
          super
          resources.each { |resource| relate_resource(resource) }
          self
        end

        def replace(other)
          assert_mutable
          each { |resource| orphan_resource(resource) }
          super
          other.each { |resource| relate_resource(resource) }
          self
        end

        def pop
          assert_mutable
          orphan_resource(super)
        end

        def shift
          assert_mutable
          orphan_resource(super)
        end

        def delete(resource, &block)
          assert_mutable
          orphan_resource(super)
        end

        def delete_at(index)
          assert_mutable
          orphan_resource(super)
        end

        def clear
          assert_mutable
          each { |resource| orphan_resource(resource) }
          super
          self
        end

        # FIXME: remove when RelationshipChain#get_children can return a Collection
        def create(attributes = {})
          assert_mutable
          super
        end

        # FIXME: remove when RelationshipChain#get_children can return a Collection
        def update(attributes = {})
          assert_mutable
          super
        end

        # FIXME: remove when RelationshipChain#get_children can return a Collection
        def destroy
          assert_mutable
          super
        end

        def save
          assert_mutable

          # save every resource in the collection
          each { |resource| save_resource(resource) }

          # save orphan resources
          @orphans.each do |resource|
            begin
              save_resource(resource, nil)
            rescue
              children << resource unless children.frozen? || children.include?(resource)
              raise
            end
          end

          # FIXME: remove when RelationshipChain#get_children can return a Collection
          # place the children into a Collection if not already
          if children.kind_of?(Array) && !children.frozen?
            @children = @relationship.get_children(@parent).replace(children)
          end

          true
        end

        def kind_of?(klass)
          super || children.kind_of?(klass)
        end

        def respond_to?(method, include_private = false)
          super || children.respond_to?(method, include_private)
        end

        private

        def initialize(relationship, parent)
          raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless relationship.kind_of?(Relationship)
          raise ArgumentError, "+parent+ should be a DataMapper::Resource, but was #{parent.class}", caller                              unless parent.kind_of?(Resource)

          @relationship = relationship
          @parent       = parent
          @orphans      = []
        end

        def children
          @children ||= @relationship.get_children(@parent)
        end

        def assert_mutable
          raise ImmutableAssociationError, 'You can not modify this assocation' if children.frozen?
        end

        def add_default_association_values(resource)
          default_attributes = if respond_to?(:default_attributes)
            self.default_attributes
          else
            @relationship.query.reject do |attribute, value|
              Query::OPTIONS.include?(attribute) || attribute.kind_of?(Query::Operator)
            end
          end

          default_attributes.each do |attribute, value|
            next if resource.attribute_loaded?(attribute)
            resource.send("#{attribute}=", value)
          end
        end

        def relate_resource(resource)
          assert_mutable
          add_default_association_values(resource)
          @orphans.delete(resource)
          resource
        end

        def orphan_resource(resource)
          assert_mutable
          @orphans << resource
          resource
        end

        def save_resource(resource, parent = @parent)
          repository(@relationship.repository_name) do
            @relationship.attach_parent(resource, parent)
            resource.save
          end
        end

        def method_missing(method, *args, &block)
          results = children.__send__(method, *args, &block)

          return self if LazyArray::RETURN_SELF.include?(method) && results.kind_of?(Array)

          results
        end
      end # class Proxy
    end # module OneToMany
  end # module Associations
end # module DataMapper
