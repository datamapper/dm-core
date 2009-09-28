# TODO: update Model#respond_to? to return true if method_method missing
# would handle the message

module DataMapper
  module Model
    module Relationship
      Model.append_extensions self

      include Extlib::Assertions
      extend Chainable

      # Initializes relationships hash for extended model
      # class.
      #
      # When model calls has n, has 1 or belongs_to, relationships
      # are stored in that hash: keys are repository names and
      # values are relationship sets.
      #
      # @api private
      def self.extended(model)
        model.instance_variable_set(:@relationships, {})
      end

      chainable do
        # When DataMapper model is inherited, relationships
        # of parent are duplicated and copied to subclass model
        #
        # @api private
        def inherited(model)
          model.instance_variable_set(:@relationships, {})

          @relationships.each do |repository_name, relationships|
            model_relationships = model.relationships(repository_name)
            relationships.each { |name, relationship| model_relationships[name] ||= relationship }
          end

          super
        end
      end

      # Returns copy of relationships set in given repository.
      #
      # @param [Symbol] repository_name
      #   Name of the repository for which relationships set is returned
      # @return [Mash]  relationships set for given repository
      #
      # @api semipublic
      def relationships(repository_name = default_repository_name)
        # TODO: create RelationshipSet#copy that will copy the relationships, but assign the
        # new Relationship objects to a supplied repository and model.  dup does not really
        # do what is needed

        @relationships[repository_name] ||= if repository_name == default_repository_name
          Mash.new
        else
          relationships(default_repository_name).dup
        end
      end

      # Used to express unlimited cardinality of association,
      # see +has+
      #
      # @api public
      def n
        1.0/0
      end

      # A shorthand, clear syntax for defining one-to-one, one-to-many and
      # many-to-many resource relationships.
      #
      #  * has 1,    :friend                             # one friend
      #  * has n,    :friends                            # many friends
      #  * has 1..3, :friends                            # many friends (at least 1, at most 3)
      #  * has 3,    :friends                            # many friends (exactly 3)
      #  * has 1,    :friend,  'User'                    # one friend with the class User
      #  * has 3,    :friends, :through => :friendships  # many friends through the friendships relationship
      #
      # @param cardinality [Integer, Range, Infinity]
      #   cardinality that defines the association type and constraints
      # @param name [Symbol]
      #   the name that the association will be referenced by
      # @param model [Model, #to_str]
      #   the target model of the relationship
      # @param opts [Hash]
      #   an options hash
      #
      # @option :through[Symbol]  A association that this join should go through to form
      #   a many-to-many association
      # @option :model[Model, String] The name of the class to associate with, if omitted
      #   then the association name is assumed to match the class name
      # @option :repository[Symbol]
      #   name of child model repository
      #
      # @return [Association::Relationship] the relationship that was
      #   created to reflect either a one-to-one, one-to-many or many-to-many
      #   relationship
      # @raise [ArgumentError] if the cardinality was not understood. Should be a
      #   Integer, Range or Infinity(n)
      #
      # @api public
      def has(cardinality, name, *args)
        assert_kind_of 'cardinality', cardinality, Integer, Range, n.class
        assert_kind_of 'name',        name,        Symbol

        model   = extract_model(args)
        options = extract_options(args)

        min, max = extract_min_max(cardinality)
        options.update(:min => min, :max => max)

        assert_valid_options(options)

        if options.key?(:model) && model
          raise ArgumentError, 'should not specify options[:model] if passing the model in the third argument'
        end

        model ||= options.delete(:model)

        repository_name = repository.name

        # TODO: change to :target_respository_name and :source_repository_name
        options[:child_repository_name]  = options.delete(:repository)
        options[:parent_repository_name] = repository_name

        klass = if options[:max] > 1
          options.key?(:through) ? Associations::ManyToMany::Relationship : Associations::OneToMany::Relationship
        else
          Associations::OneToOne::Relationship
        end

        relationship = relationships(repository_name)[name] = klass.new(name, model, self, options)

        descendants.each do |descendant|
          descendant.relationships(repository_name)[name] ||= relationship
        end

        relationship
      end

      # A shorthand, clear syntax for defining many-to-one resource relationships.
      #
      #  * belongs_to :user                              # many to one user
      #  * belongs_to :friend, :model => 'User'          # many to one friend
      #  * belongs_to :reference, :repository => :pubmed # association for repository other than default
      #
      # @param name [Symbol]
      #   the name that the association will be referenced by
      # @param model [Model, #to_str]
      #   the target model of the relationship
      # @param opts [Hash]
      #   an options hash
      #
      # @option :model[Model, String] The name of the class to associate with, if omitted
      #   then the association name is assumed to match the class name
      # @option :repository[Symbol]
      #   name of child model repository
      #
      # @return [Association::Relationship] The association created
      #   should not be accessed directly
      #
      # @api public
      def belongs_to(name, *args)
        assert_kind_of 'name', name, Symbol

        model   = extract_model(args)
        options = extract_options(args)

        if options.key?(:through)
          warn "#{self.name}#belongs_to with :through is deprecated, use 'has 1, :#{name}, #{options.inspect}' in #{self.name} instead (#{caller[0]})"
          return has(1, name, model, options)
        end

        assert_valid_options(options)

        if options.key?(:model) && model
          raise ArgumentError, 'should not specify options[:model] if passing the model in the third argument'
        end

        model ||= options.delete(:model)

        repository_name = repository.name

        # TODO: change to source_repository_name and target_respository_name
        options[:child_repository_name]  = repository_name
        options[:parent_repository_name] = options.delete(:repository)

        relationship = relationships(repository_name)[name] = Associations::ManyToOne::Relationship.new(name, self, model, options)

        descendants.each do |descendant|
          descendant.relationships(repository_name)[name] ||= relationship
        end

        relationship
      end

      private

      # Extract the model from an Array of arguments
      #
      # @param [Array(Model, String, Hash)]
      #   The arguments passed to an relationship declaration
      #
      # @return [Model, #to_str]
      #   target model for the association
      #
      # @api private
      def extract_model(args)
        model = args.first

        if model.kind_of?(Model)
          model
        elsif model.respond_to?(:to_str)
          model.to_str
        else
          nil
        end
      end

      # Extract the model from an Array of arguments
      #
      # @param [Array(Model, String, Hash)]
      #   The arguments passed to an relationship declaration
      #
      # @return [Hash]
      #   options for the association
      #
      # @api private
      def extract_options(args)
        options = args.last

        if options.kind_of?(Hash)
          options.dup
        else
          {}
        end
      end

      # A support method for converting Integer, Range or Infinity values into two
      # values representing the minimum and maximum cardinality of the association
      #
      # @return [Array]  A pair of integers, min and max
      #
      # @api private
      def extract_min_max(cardinality)
        case cardinality
          when Integer then [ cardinality,       cardinality      ]
          when Range   then [ cardinality.first, cardinality.last ]
          when n       then [ 0,                 n                ]
        end
      end

      # Validates options of association method like belongs_to or has:
      # verifies types of cardinality bounds, repository, association class,
      # keys and possible values of :through option.
      #
      # @api private
      def assert_valid_options(options)
        # TODO: update to match Query#assert_valid_options
        #   - perform options normalization elsewhere

        if options.key?(:min) && options.key?(:max)
          assert_kind_of 'options[:min]', options[:min], Integer
          assert_kind_of 'options[:max]', options[:max], Integer, n.class

          if options[:min] == n && options[:max] == n
            raise ArgumentError, 'Cardinality may not be n..n.  The cardinality specifies the min/max number of results from the association'
          elsif options[:min] > options[:max]
            raise ArgumentError, "Cardinality min (#{options[:min]}) cannot be larger than the max (#{options[:max]})"
          elsif options[:min] < 0
            raise ArgumentError, "Cardinality min much be greater than or equal to 0, but was #{options[:min]}"
          elsif options[:max] < 1
            raise ArgumentError, "Cardinality max much be greater than or equal to 1, but was #{options[:max]}"
          end
        end

        if options.key?(:repository)
          assert_kind_of 'options[:repository]', options[:repository], Repository, Symbol

          if options[:repository].kind_of?(Repository)
            options[:repository] = options[:repository].name
          end
        end

        if options.key?(:class_name)
          assert_kind_of 'options[:class_name]', options[:class_name], String
          warn "+options[:class_name]+ is deprecated, use :model instead (#{caller[1]})"
          options[:model] = options.delete(:class_name)
        end

        if options.key?(:remote_name)
          assert_kind_of 'options[:remote_name]', options[:remote_name], Symbol
          warn "+options[:remote_name]+ is deprecated, use :via instead (#{caller[1]})"
          options[:via] = options.delete(:remote_name)
        end

        if options.key?(:through)
          assert_kind_of 'options[:through]', options[:through], Symbol, Module
        end

        [ :via, :inverse ].each do |key|
          if options.key?(key)
            assert_kind_of "options[#{key.inspect}]", options[key], Symbol, Associations::Relationship
          end
        end

        # TODO: deprecate :child_key and :parent_key in favor of :source_key and
        # :target_key (will mean something different for each relationship)

        [ :child_key, :parent_key ].each do |key|
          if options.key?(key)
            assert_kind_of "options[#{key.inspect}]", options[key], Enumerable
          end
        end

        if options.key?(:limit)
          raise ArgumentError, '+options[:limit]+ should not be specified on a relationship'
        end
      end

      chainable do
        # TODO: document
        # @api public
        def method_missing(method, *args, &block)
          if relationship = relationships(repository_name)[method]
            return Query::Path.new([ relationship ])
          end

          super
        end
      end
    end # module Relationship
  end # module Model
end # module DataMapper
