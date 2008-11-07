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
            @#{name}_association ||= begin
              unless relationship = model.relationships(#{repository_name.inspect})[#{name.inspect}]
                raise ArgumentError, "Relationship #{name.inspect} does not exist in \#{model}"
              end
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

        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? respond_to? assert_kind_of should should_not instance_variable_set instance_variable_get ].include?(m) }

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

        # TODO: document
        # @api public
        def <<(resource)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          # TODO: remove this block because it should be possible to
          # move a child from one association to another.
          if !resource.new_record? && self.include?(resource)
            return self
          end
          super
          relate_resource(resource)
          self
        end

        # TODO: document
        # @api public
        def push(*resources)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          super
          resources.each { |r| relate_resource(r) }
          self
        end

        # TODO: document
        # @api public
        def unshift(*resources)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          super
          resources.each { |r| relate_resource(r) }
          self
        end

        # TODO: document
        # @api public
        def replace(other)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          each { |r| orphan_resource(r) }
          other = other.map do |r|
            if r.kind_of?(Hash)
              new_child(r)
            else
              r
            end
          end
          super
          other.each { |r| relate_resource(r) }
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
          attributes = default_attributes.merge(attributes)  # TODO: test moving this into the "else" branch below
          if children.respond_to?(:build)
            super(attributes)
          else
            # XXX: move to ManyToMany::Proxy?
            new_child(attributes)
          end
        end

        # @api public
        # @deprecated
        def new(attributes = {})
          warn "#{self.class}#new is deprecated, use #{self.class}#build instead"
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          if @parent.new_record?
            raise UnsavedParentError, 'You cannot intialize until the parent is saved'
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
            raise UnsavedParentError, 'You cannot create until the parent is saved'
          end
          attributes = default_attributes.merge(attributes)
          resource = if children.respond_to?(:create)
            super(attributes)
          else
            # XXX: move to ManyToMany::Proxy?
            @relationship.child_model.create(attributes)
          end
          self << resource  # XXX: does this result in the resource being appended twice?
          resource
        end

        # TODO: document
        # @api public
        def update(attributes = {})
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          if @parent.new_record?
            raise UnsavedParentError, 'You cannot mass-update until the parent is saved'
          end
          super
        end

        # TODO: document
        # @api public
        def update!(attributes = {})
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          if @parent.new_record?
            raise UnsavedParentError, 'You cannot mass-update without validations until the parent is saved'
          end
          super
        end

        # TODO: document
        # @api public
        def destroy
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          if @parent.new_record?
            raise UnsavedParentError, 'You cannot mass-delete until the parent is saved'
          end
          super
        end

        # TODO: document
        # @api public
        def destroy!
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          if @parent.new_record?
            raise UnsavedParentError, 'You cannot mass-delete without validations until the parent is saved'
          end
          super
        end

        # TODO: document
        # @api public
        def reload(query = {})
          children.reload(query)
          self
        end

        # TODO: document
        # @api semipublic
        def save
          if children.frozen?
            return true
          end

          # save every resource in the collection
          each { |r| save_resource(r) }

          # save orphan resources
          @orphans.each do |r|
            # XXX: this begin/rescue block is dumb.  nowhere else do we attempt
            # to rescue similar errors.  try to remove this block
            begin
              save_resource(r, nil)
            rescue
              # TODO: remove children_frozen? below once save() is specced
              # because the guard clause at the beginning should make it
              # impossible for this to ever return true
              unless children.frozen? || children.include?(r)
                children << r
              end
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

        # TODO: document
        # @api public
        def kind_of?(klass)
          super || children.kind_of?(klass)
        end

        # TODO: document
        # @api public
        def respond_to?(method, include_private = false)
          super || children.respond_to?(method, include_private)
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

          @relationship.child_key.zip(@relationship.parent_key.get(@parent)) do |property,value|
            default_attributes[property.name] = value
          end

          default_attributes
        end

        # TODO: document
        # @api private
        def add_default_association_values(resource)
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
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          add_default_association_values(resource)
          @orphans.delete(resource)
          resource
        end

        # TODO: document
        # @api private
        def orphan_resource(resource)
          assert_mutable  # XXX: move to ManyToMany::Proxy?
          @orphans << resource
          resource
        end

        # TODO: document
        # @api private
        def save_resource(resource, parent = @parent)
          @relationship.with_repository(resource) do
            if parent.nil? && resource.model.respond_to?(:many_to_many)
              # XXX: move to ManyToMany::Proxy?
              resource.destroy
            else
              # TODO: move the attach_parent call to relate_resource and orphan_resource
              # once save() is totally speced.  I believe the resource's FK values should
              # be updated immediately rather than waiting until save() is executed
              @relationship.attach_parent(resource, parent)
              resource.save
            end
          end
        end

        # TODO: document
        # @api private
        def method_missing(method, *args, &block)
          results = if children.respond_to?(method)
            children.__send__(method, *args, &block)
          end

          if LazyArray::RETURN_SELF.include?(method) && results.kind_of?(Array)
            return self
          end

          results
        end
      end # class Proxy
    end # module OneToMany
  end # module Associations
end # module DataMapper
