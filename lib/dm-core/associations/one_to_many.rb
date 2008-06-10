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
              relationship = self.class.relationships(#{repository_name.inspect})[#{name.inspect}]
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

      class Proxy
        # TODO: add assertions when attempting to perform operations
        # on the proxy when the parent is a new record and the underlying
        # children are an Array.  Will not be able to use .all(),
        # or .first(), or .destroy() for example.

        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? respond_to? should should_not ].include?(m) }

        # FIXME: remove when RelationshipChain#get_children can return a Collection
        def all(query = {})
          query.empty? ? self : @relationship.get_children(@parent_resource, query)
        end

        # FIXME: remove when RelationshipChain#get_children can return a Collection
        def first(*args)
          if args.last.respond_to?(:merge)
            query = args.pop
            @relationship.get_children(@parent_resource, query, :first, *args)
          else
            super
          end
        end

        def replace(resources)
          each { |resource| orphan_resource(resource) }
          resources.each { |resource| relate_resource(resource) }
          super
        end

        def push(*resources)
          resources.each { |resource| relate_resource(resource) }
          super
        end

        def unshift(*resources)
          resources.each { |resource| relate_resource(resource) }
          super
        end

        def <<(resource)
          assert_mutable
          #
          # The order here is of the essence.
          #
          # self.relate_resource used to be called before children.<<, which created weird errors
          # where the resource was appended in the db before it was appended onto the @children
          # structure, that was just read from the database, and therefore suddenly had two
          # elements instead of one after the first addition.
          #
          super
          relate_resource(resource)
          self
        end

        def pop
          orphan_resource(super)
        end

        def shift
          orphan_resource(super)
        end

        def delete(resource, &block)
          orphan_resource(super)
        end

        def delete_at(index)
          orphan_resource(super)
        end

        def clear
          each { |resource| orphan_resource(resource) }
          super
          self
        end

        def save
          @dirty_children.each { |resource| save_resource(resource) }
          @dirty_children = []
          @children = @relationship.get_children(@parent_resource).replace(children) unless children.frozen?
          self
        end

        def reload!
          @dirty_children = []
          @children = nil
          self
        end

        def kind_of?(klass)
          super || children.kind_of?(klass)
        end

        def respond_to?(method)
          super || children.respond_to?(method)
        end

        private

        def initialize(relationship, parent_resource)
          raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless relationship.kind_of?(Relationship)
          raise ArgumentError, "+parent_resource+ should be a DataMapper::Resource, but was #{parent_resource.class}", caller            unless parent_resource.kind_of?(Resource)

          @relationship    = relationship
          @parent_resource = parent_resource
          @dirty_children  = []
        end

        def children
          @children ||= @relationship.get_children(@parent_resource)
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
            resource.send("#{attribute}=", value) if resource.send(attribute).nil?
          end
        end

        def relate_resource(resource)
          assert_mutable
          add_default_association_values(resource)
          if @parent_resource.new_record?
            @dirty_children << resource
          else
            save_resource(resource)
          end
          resource
        end

        def orphan_resource(resource)
          begin
            save_resource(resource, nil)
          rescue
            children << resource unless children.frozen? || children.include?(resource)
            raise
          end
          resource
        end

        def save_resource(resource, parent = @parent_resource)
          assert_mutable
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
