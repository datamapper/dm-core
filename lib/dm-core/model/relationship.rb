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

        default_repository_name = self.default_repository_name

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
        Infinity
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
        assert_kind_of 'cardinality', cardinality, Integer, Range, Infinity.class
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

        klass = if max > 1
          options.key?(:through) ? Associations::ManyToMany::Relationship : Associations::OneToMany::Relationship
        else
          Associations::OneToOne::Relationship
        end

        relationship = relationships(repository_name)[name] = klass.new(name, model, self, options)

        descendants.each do |descendant|
          descendant.relationships(repository_name)[name] ||= relationship
        end

        create_relationship_reader(relationship)
        create_relationship_writer(relationship)

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

        model_name = self.name
        model      = extract_model(args)
        options    = extract_options(args)

        if options.key?(:through)
          warn "#{model_name}#belongs_to with :through is deprecated, use 'has 1, :#{name}, #{options.inspect}' in #{model_name} instead (#{caller[0]})"
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

        create_relationship_reader(relationship)
        create_relationship_writer(relationship)

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
          when Integer  then [ cardinality,       cardinality      ]
          when Range    then [ cardinality.first, cardinality.last ]
          when Infinity then [ 0,                 Infinity         ]
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

        caller_method = caller[1]

        if options.key?(:min) && options.key?(:max)
          min = options[:min]
          max = options[:max]

          assert_kind_of 'options[:min]', min, Integer
          assert_kind_of 'options[:max]', max, Integer, Infinity.class

          if min == Infinity && max == Infinity
            raise ArgumentError, 'Cardinality may not be n..n.  The cardinality specifies the min/max number of results from the association'
          elsif min > max
            raise ArgumentError, "Cardinality min (#{min}) cannot be larger than the max (#{max})"
          elsif min < 0
            raise ArgumentError, "Cardinality min much be greater than or equal to 0, but was #{min}"
          elsif max < 1
            raise ArgumentError, "Cardinality max much be greater than or equal to 1, but was #{max}"
          end
        end

        if options.key?(:repository)
          repository = options[:repository]

          assert_kind_of 'options[:repository]', repository, Repository, Symbol

          if repository.kind_of?(Repository)
            options[:repository] = repository.name
          end
        end

        if options.key?(:class_name)
          assert_kind_of 'options[:class_name]', options[:class_name], String
          warn "+options[:class_name]+ is deprecated, use :model instead (#{caller_method})"
          options[:model] = options.delete(:class_name)
        end

        if options.key?(:remote_name)
          assert_kind_of 'options[:remote_name]', options[:remote_name], Symbol
          warn "+options[:remote_name]+ is deprecated, use :via instead (#{caller_method})"
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
          if options.key?(key) && !options[key].is_a?(Enumerable)
            options[key] = Array(options[key])
          end
        end

        if options.key?(:limit)
          raise ArgumentError, '+options[:limit]+ should not be specified on a relationship'
        end
      end

      # Dynamically defines reader method
      #
      # @api private
      def create_relationship_reader(relationship)
        name        = relationship.name
        reader_name = name.to_s

        return if resource_method_defined?(reader_name)

        reader_visibility = relationship.reader_visibility

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{reader_visibility}                               # public
          def #{reader_name}(query = nil)                    # def author(query = nil)
            relationships[#{name.inspect}].get(self, query)  #   relationships[:author].get(self, query)
          end                                                # end
        RUBY
      end

      # Dynamically defines writer method
      #
      # @api private
      def create_relationship_writer(relationship)
        name        = relationship.name
        writer_name = "#{name}="

        return if resource_method_defined?(writer_name)

        writer_visibility = relationship.writer_visibility

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{writer_visibility}                                # public
          def #{writer_name}(target)                          # def author=(target)
            relationships[#{name.inspect}].set(self, target)  #   relationships[:author].set(self, target)
          end                                                 # end
        RUBY
      end

      chainable do
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
