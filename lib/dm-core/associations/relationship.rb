# TODO: move argument and option validation into the class

module DataMapper
  module Associations
    # Base class for relationships. Each type of relationship
    # (1 to 1, 1 to n, n to m) implements a subclass of this class
    # with methods like get and set overridden.
    class Relationship
      include Extlib::Assertions

      OPTIONS = [ :child_repository_name, :parent_repository_name, :child_key, :parent_key, :min, :max, :inverse, :reader_visibility, :writer_visibility ].to_set

      # Relationship name
      #
      # @example for :parent association in
      #
      #   class VersionControl::Commit
      #     # ...
      #
      #     belongs_to :parent
      #   end
      #
      # name is :parent
      #
      # @api semipublic
      attr_reader :name

      # Options used to set up association of this relationship
      #
      # @example for :author association in
      #
      #   class VersionControl::Commit
      #     # ...
      #
      #     belongs_to :author, :model => 'Person'
      #   end
      #
      # options is a hash with a single key, :model
      #
      # @api semipublic
      attr_reader :options

      # ivar used to store collection of child options in source
      #
      # @example for :commits association in
      #
      #   class VersionControl::Branch
      #     # ...
      #
      #     has n, :commits
      #   end
      #
      # instance variable name for source will be @commits
      #
      # @api semipublic
      attr_reader :instance_variable_name

      # Repository from where child objects are loaded
      #
      # @api semipublic
      attr_reader :child_repository_name

      # Repository from where parent objects are loaded
      #
      # @api semipublic
      attr_reader :parent_repository_name

      # Minimum number of child objects for relationship
      #
      # @example for :cores association in
      #
      #   class CPU::Multicore
      #     # ...
      #
      #     has 2..n, :cores
      #   end
      #
      # minimum is 2
      #
      # @api semipublic
      attr_reader :min

      # Maximum number of child objects for
      # relationship
      #
      # @example for :fouls association in
      #
      #   class Basketball::Player
      #     # ...
      #
      #     has 0..5, :fouls
      #   end
      #
      # maximum is 5
      #
      # @api semipublic
      attr_reader :max

      # Returns the visibility for the source accessor
      #
      # @return [Symbol]
      #   the visibility for the accessor added to the source
      #
      # @api semipublic
      attr_reader :reader_visibility

      # Returns the visibility for the source mutator
      #
      # @return [Symbol]
      #   the visibility for the mutator added to the source
      #
      # @api semipublic
      attr_reader :writer_visibility

      # Returns query options for relationship.
      #
      # For this base class, always returns query options
      # has been initialized with.
      # Overriden in subclasses.
      #
      # @api private
      attr_reader :query

      # Returns the String the Relationship would use in a Hash
      #
      # @return [String]
      #   String name for the Relationship
      #
      # @api private
      def field
        name.to_s
      end

      # Returns a hash of conditions that scopes query that fetches
      # target object
      #
      # @return [Hash]
      #   Hash of conditions that scopes query
      #
      # @api private
      def source_scope(source)
        { inverse => source }
      end

      # Creates and returns Query instance that fetches
      # target resource(s) (ex.: articles) for given target resource (ex.: author)
      #
      # @api semipublic
      def query_for(source, other_query = nil)
        repository_name = relative_target_repository_name_for(source)

        DataMapper.repository(repository_name).scope do
          query = target_model.query.dup
          query.update(self.query)
          query.update(:conditions => source_scope(source))
          query.update(other_query) if other_query
          query.update(:fields => query.fields | target_key)
        end
      end

      # Returns model class used by child side of the relationship
      #
      # @return [Resource]
      #   Model for association child
      #
      # @api private
      def child_model
        return @child_model if defined?(@child_model)
        child_model_name = self.child_model_name
        @child_model = (@parent_model || Object).find_const(child_model_name)
      rescue NameError
        raise NameError, "Cannot find the child_model #{child_model_name} for #{parent_model_name} in #{name}"
      end

      # @api private
      def child_model?
        child_model
        true
      rescue NameError
        false
      end

      # @api private
      def child_model_name
        @child_model ? child_model.name : @child_model_name
      end

      # Returns a set of keys that identify the target model
      #
      # @return [PropertySet]
      #   a set of properties that identify the target model
      #
      # @api semipublic
      def child_key
        return @child_key if defined?(@child_key)

        repository_name = child_repository_name || parent_repository_name
        properties      = child_model.properties(repository_name)

        @child_key = if @child_properties
          child_key = properties.values_at(*@child_properties)
          properties.class.new(child_key).freeze
        else
          properties.key
        end
      end

      # Access Relationship#child_key directly
      #
      # @api private
      alias relationship_child_key child_key
      private :relationship_child_key

      # Returns model class used by parent side of the relationship
      #
      # @return [Resource]
      #   Class of association parent
      #
      # @api private
      def parent_model
        return @parent_model if defined?(@parent_model)
        parent_model_name = self.parent_model_name
        @parent_model = (@child_model || Object).find_const(parent_model_name)
      rescue NameError
        raise NameError, "Cannot find the parent_model #{parent_model_name} for #{child_model_name} in #{name}"
      end

      # @api private
      def parent_model?
        parent_model
        true
      rescue NameError
        false
      end

      # @api private
      def parent_model_name
        @parent_model ? parent_model.name : @parent_model_name
      end

      # Returns a set of keys that identify parent model
      #
      # @return [PropertySet]
      #   a set of properties that identify parent model
      #
      # @api private
      def parent_key
        return @parent_key if defined?(@parent_key)

        repository_name = parent_repository_name || child_repository_name
        properties      = parent_model.properties(repository_name)

        @parent_key = if @parent_properties
          parent_key = properties.values_at(*@parent_properties)
          properties.class.new(parent_key).freeze
        else
          properties.key
        end
      end

      # Loads and returns "other end" of the association.
      # Must be implemented in subclasses.
      #
      # @api semipublic
      def get(resource, other_query = nil)
        raise NotImplementedError, "#{self.class}#get not implemented"
      end

      # Gets "other end" of the association directly
      # as @ivar on given resource. Subclasses usually
      # use implementation of this class.
      #
      # @api semipublic
      def get!(resource)
        resource.instance_variable_get(instance_variable_name)
      end

      # Sets value of the "other end" of association
      # on given resource. Must be implemented in subclasses.
      #
      # @api semipublic
      def set(resource, association)
        raise NotImplementedError, "#{self.class}#set not implemented"
      end

      # Sets "other end" of the association directly
      # as @ivar on given resource. Subclasses usually
      # use implementation of this class.
      #
      # @api semipublic
      def set!(resource, association)
        resource.instance_variable_set(instance_variable_name, association)
      end

      # Eager load the collection using the source as a base
      #
      # @param [Collection] source
      #   the source collection to query with
      # @param [Query, Hash] query
      #   optional query to restrict the collection
      #
      # @return [Collection]
      #   the loaded collection for the source
      #
      # @api private
      def eager_load(source, query = nil)
        targets = source.model.all(query_for(source, query))

        # FIXME: cannot associate targets to m:m collection yet
        if source.loaded? && !source.kind_of?(ManyToMany::Collection)
          associate_targets(source, targets)
        end

        targets
      end

      # Checks if "other end" of association is loaded on given
      # resource.
      #
      # @api semipublic
      def loaded?(resource)
        assert_kind_of 'resource', resource, source_model

        resource.instance_variable_defined?(instance_variable_name)
      end

      # Test the resource to see if it is a valid target
      #
      # @param [Object] source
      #   the resource or collection to be tested
      #
      # @return [Boolean]
      #   true if the resource is valid
      #
      # @api semipulic
      def valid?(value, negated = false)
        case value
          when Enumerable then valid_target_collection?(value, negated)
          when Resource   then valid_target?(value)
          when nil        then true
          else
            raise ArgumentError, "+value+ should be an Enumerable, Resource or nil, but was a #{value.class.name}"
        end
      end

      # Compares another Relationship for equality
      #
      # @param [Relationship] other
      #   the other Relationship to compare with
      #
      # @return [Boolean]
      #   true if they are equal, false if not
      #
      # @api public
      def eql?(other)
        return true if equal?(other)
        instance_of?(other.class) && cmp?(other, :eql?)
      end

      # Compares another Relationship for equivalency
      #
      # @param [Relationship] other
      #   the other Relationship to compare with
      #
      # @return [Boolean]
      #   true if they are equal, false if not
      #
      # @api public
      def ==(other)
        return true  if equal?(other)
        other.respond_to?(:cmp_repository?, true) &&
        other.respond_to?(:cmp_model?, true)      &&
        other.respond_to?(:cmp_key?, true)        &&
        other.respond_to?(:min)                   &&
        other.respond_to?(:max)                   &&
        other.respond_to?(:query)                 &&
        cmp?(other, :==)
      end

      # Get the inverse relationship from the target model
      #
      # @api semipublic
      def inverse
        return @inverse if defined?(@inverse)

        @inverse = options[:inverse]

        if kind_of_inverse?(@inverse)
          return @inverse
        end

        relationships = target_model.relationships(relative_target_repository_name).values

        @inverse = relationships.detect { |relationship| inverse?(relationship) } ||
          invert

        @inverse.child_key

        @inverse
      end

      # @api private
      def relative_target_repository_name
        target_repository_name || source_repository_name
      end

      # @api private
      def relative_target_repository_name_for(source)
        target_repository_name || if source.respond_to?(:repository)
          source.repository.name
        else
          source_repository_name
        end
      end

      # @api private
      def hash
        source_model.hash ^ name.hash
      end

      private

      # @api private
      attr_reader :child_properties

      # @api private
      attr_reader :parent_properties

      # Initializes new Relationship: sets attributes of relationship
      # from options as well as conventions: for instance, @ivar name
      # for association is constructed by prefixing @ to association name.
      #
      # Once attributes are set, reader and writer are created for
      # the resource association belongs to
      #
      # @api semipublic
      def initialize(name, child_model, parent_model, options = {})
        initialize_object_ivar('child_model',  child_model)
        initialize_object_ivar('parent_model', parent_model)

        @name                   = name
        @instance_variable_name = "@#{@name}".freeze
        @options                = options.dup.freeze
        @child_repository_name  = @options[:child_repository_name]
        @parent_repository_name = @options[:parent_repository_name]
        @child_properties       = @options[:child_key].try_dup.freeze
        @parent_properties      = @options[:parent_key].try_dup.freeze
        @min                    = @options[:min]
        @max                    = @options[:max]
        @reader_visibility      = @options.fetch(:reader_visibility, :public)
        @writer_visibility      = @options.fetch(:writer_visibility, :public)

        # TODO: normalize the @query to become :conditions => AndOperation
        #  - Property/Relationship/Path should be left alone
        #  - Symbol/String keys should become a Property, scoped to the target_repository and target_model
        #  - Extract subject (target) from Operator
        #    - subject should be processed same as above
        #  - each subject should be transformed into AbstractComparison
        #    object with the subject, operator and value
        #  - transform into an AndOperation object, and return the
        #    query as :condition => and_object from self.query
        #  - this should provide the best performance

        @query = @options.except(*self.class::OPTIONS).freeze
      end

      # Set the correct ivars for the named object
      #
      # This method should set the object in an ivar with the same name
      # provided, plus it should set a String form of the object in
      # a second ivar.
      #
      # @param [String]
      #   the name of the ivar to set
      # @param [#name, #to_str, #to_sym] object
      #   the object to set in the ivar
      #
      # @return [String]
      #   the String value
      #
      # @raise [ArgumentError]
      #   raise when object does not respond to expected methods
      #
      # @api private
      def initialize_object_ivar(name, object)
        if object.respond_to?(:name)
          instance_variable_set("@#{name}", object)
          initialize_object_ivar(name, object.name)
        elsif object.respond_to?(:to_str)
          instance_variable_set("@#{name}_name", object.to_str.dup.freeze)
        elsif object.respond_to?(:to_sym)
          instance_variable_set("@#{name}_name", object.to_sym)
        else
          raise ArgumentError, "#{name} does not respond to #to_str or #name"
        end

        object
      end

      # Sets the association targets in the resource
      #
      # @param [Resource] source
      #   the source to set
      # @param [Array<Resource>] targets
      #   the targets for the association
      # @param [Query, Hash] query
      #   the query to scope the association with
      #
      # @return [undefined]
      #
      # @api private
      def eager_load_targets(source, targets, query)
        raise NotImplementedError, "#{self.class}#eager_load_targets not implemented"
      end

      # @api private
      def valid_target_collection?(collection, negated)
        if collection.kind_of?(Collection)
          # TODO: move the check for model_key into Collection#reloadable?
          # since what we're really checking is a Collection's ability
          # to reload itself, which is (currently) only possible if the
          # key was loaded.
          model     = target_model
          model_key = model.key(repository.name)

          collection.model <= model                          &&
          (collection.query.fields & model_key) == model_key &&
          (collection.loaded? ? (collection.any? || negated) : true)
        else
          collection.all? { |resource| valid_target?(resource) }
        end
      end

      # @api private
      def valid_target?(target)
        target.kind_of?(target_model) &&
        source_key.valid?(target_key.get(target))
      end

      # @api private
      def valid_source?(source)
        source.kind_of?(source_model) &&
        target_key.valid?(source_key.get(source))
      end

      # @api private
      def inverse?(other)
        return true if @inverse.equal?(other)

        other != self                        &&
        kind_of_inverse?(other)              &&
        cmp_repository?(other, :==, :child)  &&
        cmp_repository?(other, :==, :parent) &&
        cmp_model?(other,      :==, :child)  &&
        cmp_model?(other,      :==, :parent) &&
        cmp_key?(other,        :==, :child)  &&
        cmp_key?(other,        :==, :parent)

        # TODO: match only when the Query is empty, or is the same as the
        # default scope for the target model
      end

      # @api private
      def inverse_name
        inverse = options[:inverse]
        if inverse.kind_of?(Relationship)
          inverse.name
        else
          inverse
        end
      end

      # @api private
      def invert
        inverse_class.new(inverse_name, child_model, parent_model, inverted_options)
      end

      # @api private
      def inverted_options
        options.only(*OPTIONS - [ :min, :max ]).update(:inverse => self)
      end

      # @api private
      def kind_of_inverse?(other)
        other.kind_of?(inverse_class)
      end

      # @api private
      def cmp?(other, operator)
        name.send(operator, other.name)           &&
        cmp_repository?(other, operator, :child)  &&
        cmp_repository?(other, operator, :parent) &&
        cmp_model?(other,      operator, :child)  &&
        cmp_model?(other,      operator, :parent) &&
        cmp_key?(other,        operator, :child)  &&
        cmp_key?(other,        operator, :parent) &&
        min.send(operator, other.min)             &&
        max.send(operator, other.max)             &&
        query.send(operator, other.query)
      end

      # @api private
      def cmp_repository?(other, operator, type)
        # if either repository is nil, then the relationship is relative,
        # and the repositories are considered equivalent
        return true unless repository_name = send("#{type}_repository_name")
        return true unless other_repository_name = other.send("#{type}_repository_name")

        repository_name.send(operator, other_repository_name)
      end

      # @api private
      def cmp_model?(other, operator, type)
        send("#{type}_model?")       &&
        other.send("#{type}_model?") &&
        send("#{type}_model").base_model.send(operator, other.send("#{type}_model").base_model)
      end

      # @api private
      def cmp_key?(other, operator, type)
        property_method = "#{type}_properties"

        self_key  = send(property_method)
        other_key = other.send(property_method)

        self_key.send(operator, other_key)
      end

      def associate_targets(source, targets)
        # TODO: create an object that wraps this logic, and when the first
        # kicker is fired, then it'll load up the collection, and then
        # populate all the other methods

        target_maps = Hash.new { |hash, key| hash[key] = [] }

        targets.each do |target|
          target_maps[target_key.get(target)] << target
        end

        Array(source).each do |source|
          key = source_key.get(source)
          eager_load_targets(source, target_maps[key], query)
        end
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
