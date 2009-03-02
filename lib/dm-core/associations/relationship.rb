module DataMapper
  module Associations
    # Base class for relationships. Each type of relationship
    # (1 to 1, 1 to n, n to m) implements a subclass of this class
    # with methods like get and set overridden.
    class Relationship
      OPTIONS = [ :child_repository_name, :parent_repository_name, :child_key, :parent_key, :min, :max, :through ].to_set.freeze

      # Relationship name
      #
      # Example: for :parent association in
      #
      # class VersionControl::Commit
      #   include ::DataMapper::Resource
      #
      #   belongs_to :parent
      # end
      #
      # name is :parent
      #
      # @api semipublic
      attr_reader :name

      # Options used to set up association
      # of this relationship
      #
      # Example: for :author association in
      #
      # class VersionControl::Commit
      #   include ::DataMapper::Resource
      #
      #   belongs_to :author, :model => 'Person'
      # end
      #
      # options is a hash with a single key, :model
      #
      # @api semipublic
      attr_reader :options

      # @ivar used to store collection of child options
      # in parent
      #
      # Example: for :commits association in
      #
      # class VersionControl::Branch
      #   include ::DataMapper::Resource
      #
      #   has n, :commits
      # end
      #
      # instance variable name for parent will be
      # @commits
      #
      # @api semipublic
      attr_reader :instance_variable_name

      # Repository from where child objects
      # are loaded
      #
      # @api semipublic
      attr_reader :child_repository_name

      # Repository from where parent objects
      # are loaded
      #
      # @api semipublic
      attr_reader :parent_repository_name

      # Minimum number of child objects for
      # relationship
      #
      # Example: for :cores association in
      #
      # class CPU::Multicore
      #   include ::DataMapper::Resource
      #
      #   has n, :cores, :min => 2
      # end
      #
      # minimum is 2
      #
      # @api semipublic
      attr_reader :min

      # Maximum number of child objects for
      # relationship
      #
      # Example: for :fouls association in
      #
      # class Basketball::Player
      #   include ::DataMapper::Resource
      #
      #   has n, :fouls, :max => 5
      # end
      #
      # maximum is 5
      #
      # @api semipublic
      attr_reader :max

      # Intermediate association for join model
      # relationships
      #
      # Example: for :bugs association in
      #
      # class Software::Engineer
      #   include ::DataMapper::Resource
      #
      #   has n, :missing_tests
      #   has n, :bugs, :through => :missing_tests
      # end
      #
      # through is :missing_tests
      #
      # TODO: document a case when
      # through option is a model and
      # not an association name
      #
      # @api semipublic
      attr_reader :through

      # Intermediate relationships in a "through" association.
      # Always returns empty frozen Array for this base class,
      # must be overriden in subclasses.
      #
      # @api semipublic
      def intermediaries
        @intermediaries ||= [].freeze
      end

      # Returns query object for relationship.
      # For this base class, always returns query object
      # has been initialized with.
      # Overriden in subclasses.
      #
      # @api private
      def query
        # TODO: make sure the model scope is merged in
        @query
      end

      # Returns model class used by child side of the relationship
      #
      # @returns [DataMapper::Resource] Class of association child
      # @api semipublic
      def child_model
        @child_model ||= (@parent_model || Object).find_const(@child_model_name)
      rescue NameError
        raise NameError, "Cannot find the child_model #{@child_model_name} for #{@parent_model || @parent_model_name} in #{name}"
      end

      # Returns a set of keys that identify child model
      #
      # @return   [DataMapper::PropertySet]  a set of properties that identify child model
      # @api semipublic
      def child_key
        @child_key ||=
          begin
            properties = child_model.properties(child_repository_name)

            child_key = parent_key.zip(@child_properties || []).map do |parent_property,property_name|
            property_name ||= "#{property_prefix}_#{parent_property.name}".to_sym

              properties[property_name] || begin
                options = parent_property.options.only(:length, :size, :precision, :scale)
                options.update(:index => property_prefix)

                # create the property within the correct repository
                DataMapper.repository(child_repository_name) do
                  child_model.property(property_name, parent_property.primitive, options)
                end
              end
            end

            properties.class.new(child_key).freeze
          end
      end

      # Returns model class used by parent side of the relationship
      #
      # @returns [DataMapper::Resource] Class of association parent
      # @api semipublic
      def parent_model
        @parent_model ||= (@child_model || Object).find_const(@parent_model_name)
      rescue NameError
        raise NameError, "Cannot find the parent_model #{@parent_model_name} for #{@child_model || @child_model_name} in #{name}"
      end

      # Returns a set of keys that identify parent model
      #
      # @return   [DataMapper::PropertySet]  a set of properties that identify parent model
      # @api semipublic
      def parent_key
        @parent_key ||=
          begin
            properties = parent_model.properties(parent_repository_name)

            parent_key = if @parent_properties
              properties.slice(*@parent_properties)
            else
              properties.key
            end

            properties.class.new(parent_key).freeze
          end
      end

      # Creates and returns Query instance for given
      # resource (usually a parent).
      # Must be implemented in subclasses.
      #
      # @api semipublic
      def query_for(resource)
        raise NotImplementedError
      end

      # Loads and returns "other end" of the association.
      # Must be implemented in subclasses.
      #
      # @api semipublic
      def get(resource, query = nil)
        raise NotImplementedError
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
        raise NotImplementedError
      end

      # Sets "other end" of the association directly
      # as @ivar on given resource. Subclasses usually
      # use implementation of this class.
      #
      # @api semipublic
      def set!(resource, association)
        resource.instance_variable_set(instance_variable_name, association)
      end

      # Checks if "other end" of association is loaded on given
      # resource.
      #
      # @api semipublic
      def loaded?(resource)
        resource.instance_variable_defined?(instance_variable_name)
      end

      private

      # Initializes new Relationship: sets attributes of relationship
      # from options as well as conventions: for instance, @ivar name
      # for association is constructed by prefixing @ to association name.
      #
      # Once attributes are set, reader and writer (called accessor and mutator in
      # DataMapper terminology) are created for the resource association belongs to
      #
      # @api semipublic
      def initialize(name, child_model, parent_model, options = {})
        case child_model
          when Model  then @child_model      = child_model
          when String then @child_model_name = child_model.dup.freeze
        end

        case parent_model
          when Model  then @parent_model      = parent_model
          when String then @parent_model_name = parent_model.dup.freeze
        end

        @name                   = name
        @instance_variable_name = "@#{@name}".freeze
        @options                = options.dup.freeze
        @child_repository_name  = @options[:child_repository_name]  || @options[:parent_repository_name]
        @parent_repository_name = @options[:parent_repository_name] || @options[:child_repository_name]
        @child_properties       = @options[:child_key].try_dup.freeze
        @parent_properties      = @options[:parent_key].try_dup.freeze
        @min                    = @options[:min]
        @max                    = @options[:max]
        @through                = @options[:through]

        query = @options.except(*OPTIONS)

        if max.kind_of?(Integer)
          query[:limit] = max
        end

        @query = query.freeze

        create_accessor
        create_mutator
      end

      # Creates reader method for association.
      # Must be implemented by subclasses.
      #
      # @api semipublic
      def create_accessor
        raise NotImplementedError
      end

      # Creates both writer method for association.
      # Must be implemented by subclasses.
      #
      # @api semipublic
      def create_mutator
        raise NotImplementedError
      end

      # Prefix used to build name of default child key
      #
      # @api private
      def property_prefix
        Extlib::Inflection.underscore(Extlib::Inflection.demodulize(parent_model.name)).to_sym
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
