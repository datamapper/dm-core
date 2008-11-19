module DataMapper
  module Associations
    module OneToMany
      extend Assertions

      # Setup one to many relationship between two models
      #
      # @api private
      def self.setup(name, model, options = {})
        assert_kind_of 'name',    name,    Symbol
        assert_kind_of 'model',   model,   Model
        assert_kind_of 'options', options, Hash

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
            @#{name} ||= begin
              relationship = model.relationships(#{repository_name.inspect})[#{name.inspect}]
              association = Proxy.new(relationship, self)
              parent_associations << association
              association
            end
          end
        EOS

        model.relationships(repository_name)[name] = if options.has_key?(:through)
          opts = options.dup

          if opts.key?(:class_name) && !opts.key?(:child_key)
            warn(<<-EOS.margin)
              You have specified #{model.base_model.name}.has(#{name.inspect}) with :class_name => #{opts[:class_name].inspect}. You probably also want to specify the :child_key option.
            EOS
          end

          opts[:child_model]            ||= opts.delete(:class_name)  || Extlib::Inflection.classify(name)
          opts[:parent_model]             =   model
          opts[:repository_name]          =   repository_name
          opts[:near_relationship_name]   =   opts.delete(:through)
          opts[:remote_relationship_name] ||= opts.delete(:remote_name) || name
          opts[:parent_key]               =   opts[:parent_key]
          opts[:child_key]                =   opts[:child_key]

          RelationshipChain.new( opts )
        else
          Relationship.new(
            name,
            repository_name,
            options.fetch(:class_name, Extlib::Inflection.classify(name)),
            model,
            options
          )
        end
      end

      # TODO: look at making this inherit from Collection.  The API is
      # almost identical, and it would make more sense for the
      # relationship.get_children method to return a Proxy than a
      # Collection that is wrapped in a Proxy.
      class Proxy
        include Assertions

        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? respond_to? assert_kind_of should should_not instance_variable_set instance_variable_get ].include?(m.to_s) }

        # TODO: document
        # @api public
        def reload(query = {})
          children.reload(query)
          self
        end

        # TODO: document
        # @api public
        # FIXME: remove when RelationshipChain#get_children can return a Collection
        def all(query = {})
          if query.empty?
            self
          else
            @relationship.get_children(@parent, query)
          end
        end

        # TODO: document
        # @api public
        # FIXME: remove when RelationshipChain#get_children can return a Collection
        def first(*args)
          if args.last.respond_to?(:merge)
            query = args.pop
            @relationship.get_children(@parent, query, :first, *args)
          else
            super
          end
        end

        # TODO: add #last

        # TODO: add #slice (returns a wrapped OneToMany::Proxy object)

        # TODO: add #slice!

        # TODO: add #collect!

        # TODO: alias #map! to #collect!

        # TODO: document
        # @api public
        def <<(resource)
          assert_mutable  # XXX: move to ManyToMany::Proxy?

          # FIXME: figure out why the following code is depended on my
          # ManyToMany::Proxy.  Commenting it out causes it's specs to fail.
          # This code should be removed.
          if !resource.new_record? && include?(resource)
            return self
          end

          relate_resource(resource)
          super
          self
        end

        # TODO: add #concat

        # TODO: add #insert

        # TODO: document
        # @api public
        def push(*resources)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          resources.each { |r| relate_resource(r) }
          super
          self
        end

        # TODO: document
        # @api public
        def unshift(*resources)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          resources.each { |r| relate_resource(r) }
          super
          self
        end

        # TODO: document
        # @api public
        def replace(other)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          each { |r| orphan_resource(r) }
          other.map! do |r|
            if r.kind_of?(Hash)
              build(r)
            else
              relate_resource(r)
            end
          end
          super
          self
        end

        # TODO: document
        # @api public
        def pop
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          orphan_resource(super)
        end

        # TODO: document
        # @api public
        def shift
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          orphan_resource(super)
        end

        # TODO: document
        # @api public
        def delete(resource)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          orphan_resource(super)
        end

        # TODO: document
        # @api public
        def delete_at(index)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          orphan_resource(super)
        end

        # TODO: add #delete_if

        # TODO: add #reject!

        # TODO: document
        # @api public
        def clear
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          each { |r| orphan_resource(r) }
          super
          self
        end

        # TODO: document
        # @api public
        def build(attributes = {})
          assert_mutable  # XXX: move to ManyToMany::Proxy?

          # TODO: test moving this into the "else" branch below
          attributes = default_attributes.merge(attributes)

          if children.respond_to?(:build)
            relate_resource(super(attributes))
          else
            # XXX: move to ManyToMany::Proxy?
            # FIXME: This should probably use << to append the resource
            new_child(attributes)
          end
        end

        # @api public
        # @deprecated
        def new(attributes = {})
          warn "#{self.class}#new is deprecated, use #{self.class}#build instead"

          assert_mutable  # XXX: move to ManyToMany::Proxy?

          if @parent.new_record?
            raise UnsavedParentError, 'The parent must be saved before initializing a Resource'
          end

          resource = new_child(attributes)
          self << resource
          resource
        end

        # TODO: document
        # @api public
        def create(attributes = {})
          assert_mutable  # XXX: move to ManyToMany::Proxy?

          if @parent.new_record?
            raise UnsavedParentError, 'The parent must be saved before creating a Resource'
          end

          attributes = default_attributes.merge(attributes)

          if children.respond_to?(:create)
            super(attributes)
          else
            # XXX: move to ManyToMany::Proxy?
            resource = @relationship.child_model.create(attributes)
            self << resource unless resource.new_record?
            resource
          end
        end

        # TODO: document
        # @api public
        def update(attributes = {}, *allowed)
          assert_mutable  # XXX: move to ManyToMany::Proxy?

          if @parent.new_record?
            raise UnsavedParentError, 'The parent must be saved before mass-updating the association'
          end

          super
        end

        # TODO: document
        # @api public
        def update!(attributes = {}, *allowed)
          assert_mutable  # XXX: move to ManyToMany::Proxy?

          if @parent.new_record?
            raise UnsavedParentError, 'The parent must be saved before mass-updating the association without validation'
          end

          super
        end

        # TODO: document
        # @api public
        def destroy
          assert_mutable  # XXX: move to ManyToMany::Proxy?

          if @parent.new_record?
            raise UnsavedParentError, 'The parent must be saved before mass-deleting the association'
          end

          super
        end

        # TODO: document
        # @api public
        def destroy!
          assert_mutable  # XXX: move to ManyToMany::Proxy?

          if @parent.new_record?
            raise UnsavedParentError, 'The parent must be saved before mass-deleting the association without validation'
          end

          super
        end

        # TODO: document
        # @api semipublic
        def save
          if children.frozen?  # XXX: move to ManyToMany::Proxy?
            return true
          end

          # save every resource in the collection
          each { |r| save_resource(r) }

          # save orphaned resources
          @orphans.each { |r| save_resource(r) }

          # XXX: move to ManyToMany::Proxy?
          if children.kind_of?(Array) && !children.frozen?
            @children = @relationship.get_children(@parent).replace(children)
          end

          true
        end

        # TODO: document
        # @api public
        def kind_of?(klass)
          super || children.kind_of?(klass)
        end

        # TODO: document
        # @api public
        def respond_to?(method, include_private = false)
          super || children.respond_to?(method)
        end

        private

        # TODO: document
        # @api public
        def initialize(relationship, parent)
          assert_kind_of 'relationship', relationship, Relationship
          assert_kind_of 'parent',       parent,       Resource

          @relationship = relationship
          @parent       = parent
          @orphans      = []
        end

        # TODO: document
        # @api private
        def children
          @children ||= @relationship.get_children(@parent)
        end

        # TODO: document
        # @api private
        def assert_mutable  # XXX: move to ManyToMany::Proxy?
          if children.frozen?
            raise ImmutableAssociationError, 'You can not modify this association'
          end
        end

        # TODO: document
        # @api private
        def default_attributes
          default_attributes = {}

          @relationship.query.each do |attribute, value|
            if Query::OPTIONS.include?(attribute) || attribute.kind_of?(Query::Operator)
              next
            end
            default_attributes[attribute] = value
          end

          # TODO: remove this if ManyToMany::Proxy does not need it
          @relationship.child_key.zip(@relationship.parent_key.get(@parent)) do |property,value|
            default_attributes[property.name] = value
          end

          default_attributes
        end

        # TODO: document
        # @api private
        def add_default_association_values(resource)  # XXX: move to ManyToMany::Proxy?
          default_attributes.each do |attribute, value|
            if !resource.respond_to?("#{attribute}=") || resource.attribute_loaded?(attribute)
              next
            end
            resource.send("#{attribute}=", value)
          end
        end

        # TODO: document
        # @api private
        def new_child(attributes)
          @relationship.child_model.new(default_attributes.merge(attributes))
        end

        # TODO: document
        # @api private
        def relate_resource(resource)
          @relationship.attach_parent(resource, @parent)
          @orphans.delete(resource)
          resource
        end

        # TODO: document
        # @api private
        def orphan_resource(resource)
          return if resource.nil?
          @relationship.attach_parent(resource, nil)
          @orphans << resource
          resource
        end

        # TODO: document
        # @api private
        def save_resource(resource)
          @relationship.with_repository(resource) do
            if @relationship.child_key.get(resource).nil? && resource.model.respond_to?(:many_to_many)
              # XXX: move to ManyToMany::Proxy?
              resource.destroy
            else
              resource.save
            end
          end
        end

        # TODO: document
        # @api public
        def method_missing(method, *args, &block)
          results = children.__send__(method, *args, &block)

          if LazyArray::RETURN_SELF.include?(method) && results.kind_of?(Array)
            return self
          end

          results
        end
      end # class Proxy
    end # module OneToMany
  end # module Associations
end # module DataMapper
