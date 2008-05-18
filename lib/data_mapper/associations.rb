dir = Pathname(__FILE__).dirname.expand_path / 'associations'

require dir / 'relationship'
require dir / 'many_to_many'
require dir / 'many_to_one'
require dir / 'one_to_many'
require dir / 'one_to_one'

module DataMapper
  module Associations
    include ManyToOne
    include OneToMany
    include ManyToMany
    include OneToOne

    def relationships(repository_name = default_repository_name)
      (@relationships ||= Hash.new { |h,k| h[k] = (k == :default || !h.key?(:default) ? {} : h[:default].dup) })[repository_name]
    end

    def n
      1.0/0
    end

    #
    # A shorthand, clear syntax for defining one-to-one, one-to-many and
    # many-to-many resource relationships.
    #
    # @example [Usage]
    #   * has 1, :friend                          # one_to_one, :friend
    #   * has n, :friends                         # one_to_many :friends
    #   * has 1..3, :friends
    #                         # one_to_many :friends, :min => 1, :max => 3
    #   * has 3, :friends
    #                         # one_to_many :friends, :min => 3, :max => 3
    #   * has 1, :friend, :class_name=>'User'
    #                         # one_to_one :friend, :class_name => 'User'
    #   * has 3, :friends, :through=>:friendships
    #                         # one_to_many :friends, :through => :friendships
    #
    # @param cardinality <Fixnum, Bignum, Infinity, Range>
    #   cardinality that defines the association type and constraints
    # @param name <Symbol>  the name that the association will be referenced by
    # @param opts <Hash>    an options hash
    #
    # @option :through<Symbol>  A association that this join should go through to form
    #       a many-to-many association
    # @option :class_name<String> The name of the class to associate with, if omitted
    #       then the association name is assumed to match the class name
    #
    # @return <DataMapper::Association::Relationship> the relationship that was
    #   created to reflect either a one-to-one, one-to-many or many-to-many
    #   relationship
    # @raise <ArgumentError> if the cardinality was not understood. Should be a
    #   Fixnum, Bignum, Infinity(n) or Range
    #
    # @api public
    def has(cardinality, name, options = {})
      options = options.merge(extract_min_max(cardinality))
      relationship = nil
      if options[:max] == 1
        relationship = one_to_one(name, options)
      else
        if options[:min] == n && options[:max] == n
          relationship = many_to_many(name, options)
        else
          relationship = one_to_many(name, options)
        end
      end
      # Please leave this in - I will release contextual serialization soon
      # which requires this -- guyvdb
      # TODO convert this to a hook in the plugin once hooks work on class
      # methods
      self.init_has_relationship_for_serialization(relationship) if self.respond_to?(:init_has_relationship_for_serialization)
    end

    #
    # A shorthand, clear syntax for defining many-to-one resource relationships.
    #
    # @example [Usage]
    #   * belongs_to :user                          # many_to_one, :friend
    #   * belongs_to :friend, :classname => 'User'  # many_to_one :friends
    #
    # @param name<Symbol> The name that the association will be referenced by
    # @param opts<Hash>   An options hash (see below)
    # @see #has
    #
    # @return <DataMapper::Association::ManyToOne> The association created
    #   should not be accessed directly
    #
    # @api public
    def belongs_to(name, options={})
      relationship = many_to_one(name, options)
      # Please leave this in - I will release contextual serialization soon
      # which requires this -- guyvdb
      # TODO convert this to a hook in the plugin once hooks work on class
      # methods
      self.init_belongs_relationship_for_serialization(relationship) if self.respond_to?(:init_belongs_relationship_for_serialization)
    end


  private

    # A support method form converting Fixnum, Range or Infinity values into a
    # {:min=>x, :max=>y} hash.
    #
    # @api private
    def extract_min_max(constraints)
      case constraints
        when Range
          raise ArgumentError, "Constraint min (#{constraints.first}) cannot be larger than the max (#{constraints.last})" if constraints.first > constraints.last
          { :min => constraints.first, :max => constraints.last }
        when Fixnum, Bignum
          { :min => constraints, :max => constraints }
        when n
          {}
        else
          raise ArgumentError, "Constraint #{constraints.inspect} (#{constraints.class}) not handled must be one of Range, Fixnum, Bignum, Infinity(n)"
      end
    end
  end # module Associations

  module Resource
    module ClassMethods
      include DataMapper::Associations
    end # module ClassMethods
  end # module Resource
end # module DataMapper
