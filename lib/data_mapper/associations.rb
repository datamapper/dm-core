dir = Pathname(__FILE__).dirname.expand_path / 'associations'

require dir / 'relationship'
require dir / 'many_to_many'
require dir / 'many_to_one'
require dir / 'one_to_many'
require dir / 'one_to_one'

module DataMapper
  module Associations
    def self.extended(base)
      base.extend ManyToOne
      base.extend OneToMany
      base.extend ManyToMany
      base.extend OneToOne
    end

    def relationships
      @relationships ||= Hash.new { |h, k| h[k] = {} }
    end

    def n
      1.0/0
    end

    #
    # A shorthand, clear syntax for defining one-to-one, one-to-many and many-to-many resource relationships.
    #
    # ==== Usage Examples...
    # * has 1, :friend                          # one_to_one, :friend
    # * has n, :friends                         # one_to_many :friends
    # * has 1..3, :friends                      # one_to_many :friends, :min => 1, :max => 3
    # * has 3, :friends                         # one_to_many :friends, :min => 3, :max => 3
    # * has 1, :friend, :class_name=>'User'     # one_to_one :friend, :class_name => 'User'
    # * has 3, :friends, :through=>:friendships # one_to_many :friends, :through => :friendships
    #
    # ==== Parameters
    # cardinality<Fixnum, Bignum, Infinity, Range>:: Defines the association type & constraints
    # name<Symbol>:: The name that the association will be referenced by
    # opts<Hash>:: An options hash (see below)
    #
    # ==== Options (opts)
    # :through<Symbol>:: A association that this join should go through to form a many-to-many association
    # :class_name<String>:: The name of the class to associate with, if ommitted then the association name is assumed to match the class name
    #
    # ==== Returns
    # DataMapper::Association::Relationship:: The relationship that was created to reflect either a one-to-one, one-to-many or many-to-many relationship
    #
    # ==== Raises
    # ArgumentError:: if the cardinality was not understood - should be Fixnum, Bignum, Infinity(n) or Range
    #
    # @public
    def has(cardinality, name, options = {})
      options = options.merge(extract_min_max(cardinality))
      relationship = nil
      if options[:max] == 1
        relationship = one_to_one(name, options)
      else
        relationship = one_to_many(name, options)
      end
      # Please leave this in - I will release contextual serialization soon which requires this -- guyvdb
      # TODO convert this to a hook in the plugin once hooks work on class methods
      self.init_has_relationship_for_serialization(relationship) if self.respond_to?(:init_has_relationship_for_serialization)
    end

    #
    # A shorthand, clear syntax for defining many-to-one resource relationships.
    #
    # ==== Usage Examples...
    # * belongs_to :user                          # many_to_one, :friend
    # * belongs_to :friend, :classname => 'User'  # many_to_one :friends
    #
    # ==== Parameters
    # name<Symbol>:: The name that the association will be referenced by
    # opts<Hash>:: An options hash (see below)
    #
    # ==== Options (opts)
    # (See has() for options)
    #
    # ==== Returns
    # DataMapper::Association::ManyToOne:: The association created should not be accessed directly
    #
    # @public
    def belongs_to(name, options={})
      relationship = many_to_one(name, options)
      # Please leave this in - I will release contextual serialization soon which requires this -- guyvdb
      # TODO convert this to a hook in the plugin once hooks work on class methods
      self.init_belongs_relationship_for_serialization(relationship) if self.respond_to?(:init_belongs_relationship_for_serialization)
    end


  private

    # A support method form converting Fixnum, Range or Infinity values into a {:min=>x, :max=>y} hash.
    #
    # @private
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
end # module DataMapper
