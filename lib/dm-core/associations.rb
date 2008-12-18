dir = Pathname(__FILE__).dirname.expand_path / 'associations'

require dir / 'relationship'
require dir / 'one_to_many'
require dir / 'one_to_one'
require dir / 'many_to_one'

module DataMapper
  module Associations
    include Assertions

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
      @relationships ||= {}
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
    #  * has 1,    :friend,  :class   => 'User'       # one friend with the class User
    #  * has 3,    :friends, :through => :friendships # many friends through the friendships relationship
    #
    # @param cardinality [Integer, Range, Infinity]
    #   cardinality that defines the association type and constraints
    # @param name <Symbol>  the name that the association will be referenced by
    # @param opts <Hash>    an options hash
    #
    # @option :through[Symbol]  A association that this join should go through to form
    #       a many-to-many association
    # @option :class[String] The name of the class to associate with, if omitted
    #       then the association name is assumed to match the class name
    # @option :remote_name[Symbol] In the case of a :through option being present, the
    #       name of the relationship on the other end of the :through-relationship
    #       to be linked to this relationship.
    #
    # @return [DataMapper::Association::Relationship] the relationship that was
    #   created to reflect either a one-to-one, one-to-many or many-to-many
    #   relationship
    # @raise [ArgumentError] if the cardinality was not understood. Should be a
    #   Integer, Range or Infinity(n)
    #
    # @api public
    def has(cardinality, name, options = {})
      assert_kind_of 'name', name, Symbol

      options = options.merge(extract_min_max(cardinality))

      assert_valid_options(options)

      parent_repository_name = repository.name

      options[:child_repository_name]  = options.delete(:repository) if options.key?(:repository)
      options[:parent_repository_name] = parent_repository_name

      # TODO: remove this once Relationships can have relative repositories
      options[:child_repository_name] ||= options[:parent_repository_name]

      klass = if options.key?(:through)
        ManyToMany::Relationship
      elsif options[:max] > 1
        OneToMany::Relationship
      else
        OneToOne::Relationship
      end

      relationships(parent_repository_name)[name] = klass.new(name, options.delete(:class), self, options)
    end

    ##
    # A shorthand, clear syntax for defining many-to-one resource relationships.
    #
    #  * belongs_to :user                      # many_to_one, :friend
    #  * belongs_to :friend, :class => 'User'  # many_to_one :friends
    #
    # @param name [Symbol] The name that the association will be referenced by
    # @see #has
    #
    # @return [DataMapper::Association::Relationship] The association created
    #   should not be accessed directly
    #
    # @api public
    def belongs_to(name, options = {})
      assert_valid_options(options)

      @_valid_relations = false

      child_repository_name = repository.name

      options[:child_repository_name]  = child_repository_name
      options[:parent_repository_name] = options.delete(:repository) if options.key?(:repository)

      # TODO: remove this once Relationships can have relative repositories
      options[:parent_repository_name] ||= options[:child_repository_name]

      relationships(child_repository_name)[name] = ManyToOne::Relationship.new(name, self, options.delete(:class), options)
    end

    private

    ##
    # A support method form converting Integer, Range or Infinity values into a
    # { :min => x, :max => y } hash.
    #
    # @raise [ArgumentError] if constraints[:min] is larger than constraints[:max]
    #
    # @api private
    def extract_min_max(constraints)
      assert_kind_of 'constraints', constraints, Integer, Range unless constraints == n

      case constraints
        when Integer
          { :min => constraints, :max => constraints }
        when Range
          if constraints.first > constraints.last
            raise ArgumentError, "Constraint min (#{constraints.first}) cannot be larger than the max (#{constraints.last})"
          end

          { :min => constraints.first, :max => constraints.last }
        when n
          { :min => 0, :max => n }
      end
    end

    # TODO: document
    # @api private
    def assert_valid_options(options)
      if options.key?(:through)
        raise ArgumentError, ':through not supported yet'
      end

      if class_name = options.delete(:class_name)
        warn "+options[:class_name]+ is deprecated, use :class instead"
        options[:class] = class_name
      end

      if (repository = options[:repository]).kind_of?(Repository)
        options[:repository] = repository.name
      end

      # do not remove this. There is alot of confusion on people's
      # part about what the first argument to has() is.  For the record it
      # is the min cardinality and max cardinality of the association.
      # simply put, it constraints the number of resources that will be
      # returned by the association.  It is not, as has been assumed,
      # the number of results on the left and right hand side of the
      # reltionship.
      if options[:min] == n && options[:max] == n
        raise ArgumentError, 'Cardinality may not be n..n.  The cardinality specifies the min/max number of results from the association', caller
      end
    end

    Model.append_extensions self
  end # module Associations
end # module DataMapper
