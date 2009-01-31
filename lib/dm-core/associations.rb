dir = Pathname(__FILE__).dirname.expand_path / 'associations'

require dir / 'relationship'
require dir / 'one_to_many'
require dir / 'one_to_one'
require dir / 'many_to_one'
require dir / 'many_to_many'

module DataMapper
  module Associations
    include Extlib::Assertions

    class UnsavedParentError < RuntimeError; end

    ##
    # Returns all relationships that are many-to-one for this model.
    #
    # Used to find the relationships that require properties in any Repository.
    #
    #  class Plur
    #    include DataMapper::Resource
    #    def self.default_repository_name
    #      :plur_db
    #    end
    #    repository(:plupp_db) do
    #      has 1, :plupp
    #    end
    #  end
    #
    # This resource has a many-to-one to the Plupp resource residing in the :plupp_db repository,
    # but the Plur resource needs the plupp_id property no matter what repository itself lives in,
    # ie we need to create that property when we migrate etc.
    #
    # Used in DataMapper::Model.properties_with_subclasses
    #
    # @api private
    def many_to_one_relationships
      relationships unless @relationships # needs to be initialized!
      @relationships.values.collect do |rels| rels.values end.flatten.select do |relationship| relationship.child_model == self end
    end

    def relationships(repository_name = default_repository_name)
      @relationships ||= Mash.new
      @relationships[repository_name] ||= repository_name == Repository.default_name ? {} : relationships(Repository.default_name).dup
    end

    def n
      1.0/0
    end

    ##
    # A shorthand, clear syntax for defining one-to-one, one-to-many and
    # many-to-many resource relationships.
    #
    #  * has 1,    :friend    # one friend
    #  * has n,    :friends   # many friends
    #  * has 1..3, :friends   # many friends (at least 1, at most 3)
    #  * has 3,    :friends   # many friends (exactly 3)
    #  * has 1,    :friend,  :model   => 'User'       # one friend with the class User
    #  * has 3,    :friends, :through => :friendships # many friends through the friendships relationship
    #
    # @param cardinality [Integer, Range, Infinity]
    #   cardinality that defines the association type and constraints
    # @param name <Symbol>  the name that the association will be referenced by
    # @param opts <Hash>    an options hash
    #
    # @option :through[Symbol]  A association that this join should go through to form
    #       a many-to-many association
    # @option :model[DataMapper::Model,String] The name of the class to associate with, if omitted
    #       then the association name is assumed to match the class name
    #
    # @return [DataMapper::Association::Relationship] the relationship that was
    #   created to reflect either a one-to-one, one-to-many or many-to-many
    #   relationship
    # @raise [ArgumentError] if the cardinality was not understood. Should be a
    #   Integer, Range or Infinity(n)
    #
    # @api public
    def has(cardinality, name, options = {})
      assert_kind_of 'cardinality', cardinality, Integer, Float, Range
      assert_kind_of 'name',        name,        Symbol
      assert_kind_of 'options',     options,     Hash

      min, max = extract_min_max(cardinality)
      options = options.merge(:min => min, :max => max)

      assert_valid_options(options)

      options[:child_repository_name]  = options.delete(:repository)
      options[:parent_repository_name] = repository.name

      klass = if options.key?(:through)
        ManyToMany::Relationship
      elsif options[:max] > 1
        OneToMany::Relationship
      else
        OneToOne::Relationship
      end

      relationships(repository.name)[name] = klass.new(name, options.delete(:model), self, options.freeze)
    end

    ##
    # A shorthand, clear syntax for defining many-to-one resource relationships.
    #
    #  * belongs_to :user                      # many to one user
    #  * belongs_to :friend, :model => 'User'  # many to one friend
    #
    # @param name [Symbol] The name that the association will be referenced by
    # @see #has
    #
    # @return [DataMapper::Association::Relationship] The association created
    #   should not be accessed directly
    #
    # @api public
    def belongs_to(name, options = {})
      assert_kind_of 'name',    name,    Symbol
      assert_kind_of 'options', options, Hash

      options = options.merge(:min => options[:min] || 0, :max => 1)

      assert_valid_options(options)

      @_valid_relations = false

      options[:child_repository_name]  = repository.name
      options[:parent_repository_name] = options.delete(:repository)

      relationships(repository.name)[name] = ManyToOne::Relationship.new(name, self, options.delete(:model), options.freeze)
    end

    private

    ##
    # A support method for converting Integer, Range or Infinity values into two
    # values representing the minimum and maximum cardinality of the association
    #
    # @api private
    def extract_min_max(cardinality)
      case cardinality
        when Integer then return cardinality, cardinality
        when Range   then return cardinality.first, cardinality.last
        when n       then return 0, n
      end
    end

    # TODO: document
    # @api private
    def assert_valid_options(options)
      # TODO: update to match Query#assert_valid_options
      #   - perform options normalization elsewhere

      assert_kind_of 'options[:min]', options[:min], Integer
      assert_kind_of 'options[:max]', options[:max], Integer, Float

      if options[:min] == n && options[:max] == n
        raise ArgumentError, 'Cardinality may not be n..n.  The cardinality specifies the min/max number of results from the association', caller(1)
      elsif options[:min] > options[:max]
        raise ArgumentError, "Cardinality min (#{options[:min]}) cannot be larger than the max (#{options[:max]})", caller(1)
      elsif options[:min] < 0
        raise ArgumentError, "Cardinality min much be greater than or equal to 0, but was #{options[:min]}", caller(1)
      elsif options[:max] < 1
        raise ArgumentError, "Cardinality max much be greater than or equal to 1, but was #{options[:max]}", caller(1)
      end

      if options.key?(:repository)
        assert_kind_of 'options[:repository]', options[:repository], Repository, Symbol

        if options[:repository].kind_of?(Repository)
          options[:repository] = options[:repository].name
        end
      end

      if options.key?(:class_name)
        assert_kind_of 'options[:class_name]', options[:class_name], String
        warn '+options[:class_name]+ is deprecated, use :model instead'
        options[:model] = options.delete(:class_name)
      end

      if options.key?(:child_key)
        assert_kind_of 'options[:child_key]', options[:child_key], Enumerable
      end

      if options.key?(:parent_key)
        assert_kind_of 'options[:parent_key]', options[:parent_key], Enumerable
      end

      if options.key?(:through) && options[:through] != Resource
        assert_kind_of 'options[:through]', options[:through], Relationship, Symbol, Module

        if (through = options[:through]).kind_of?(Symbol)
          unless options[:through] = relationships(repository.name)[through]
            raise ArgumentError, "through refers to an unknown relationship #{through} in #{self} within the #{repository.name} repository"
          end
        end
      end

      if options.key?(:limit)
        raise ArgumentError, '+options[:limit]+ should not be specified on a relationship', caller(1)
      end
    end

    Model.append_extensions self
  end # module Associations
end # module DataMapper
