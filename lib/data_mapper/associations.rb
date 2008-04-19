require __DIR__ + 'associations/many_to_one'
require __DIR__ + 'associations/one_to_many'
require __DIR__ + 'associations/many_to_many'
require __DIR__ + 'associations/one_to_one'

module DataMapper
  module Associations
    def self.extended(base)
      base.extend ManyToOne
      base.extend OneToMany
      base.extend ManyToMany
      base.extend OneToOne
    end

    def relationships
      @relationships ||= {}
    end

    def n
      1.0/0
    end
    
    #
    # A shorthand, clear syntax for defining one-to-one, one-to-many and many-to-many resource relationships.
    # 
    # Usage Examples...
    #
    # * has 1, :friend                          # one_to_one, :friend
    # * has n, :friends                         # one_to_many :friends
    # * has 1..3, :friends                      # one_to_many :friends, :min => 1, :max => 3
    # * has 3, :friends                         # one_to_many :friends, :min => 3, :max => 3
    # * has 1, :friend, :class_name=>'User'     # one_to_one :friend, :class_name => 'User'
    # * has 3, :friends, :through=>:friendships # one_to_one :friend, :class_name => 'User'
    #
    # * <tt>cardinality</tt> - can be defined as either a fixed number, Infinity or a range
    # * <tt>name</tt> - name of the resource to associate with
    # * <tt>options</tt> - A hash of additional options
    #
    def has(cardinality, name, options = {})
      case cardinality
        when Range
          min, max = cardinality.first, cardinality.last
          # 1..n or 3..5
          one_to_many(name, extract_min_max(cardinality).merge(options))
        when 1
          one_to_one(name, options)
        when Fixnum, Bignum, n              # n or 2 - shorthand form of n..n or 2..2
          one_to_many(name, extract_min_max(cardinality).merge(options))
      end || raise(ArgumentError, "Cardinality #{cardinality.inspect} (#{cardinality.class}) not handled")
    end
    
    #
    # A shorthand, clear syntax for defining many-to-one resource relationships.
    # 
    # Usage Examples...
    #
    # * belongs_to :user                          # many_to_one, :friend
    # * belongs_to :friend, :classname => 'User'  # one_to_many :friends
    #
    # * <tt>name</tt> - name of the resource to associate with
    # * <tt>options</tt> - A hash of additional options
    #
    def belongs_to(name, options={})
      many_to_one(name, options)
    end
    
    
  private 
  
    # A support method form converting Fixnum, Range or Infinity values into a {:min=>x, :max=>y} hash.
    #
    # * <tt>contraints</tt> - constraints can be defined as either a fixed number, Infinity or a range
    def extract_min_max(contraints)
      case contraints
        when Range
          {:min=>contraints.first, :max=>contraints.last}
        when Fixnum, Bignum
          {:min=>contraints, :max=>contraints}
        when n
          {}
      end || raise(ArgumentError, "Contraint #{contraints.inspect} (#{contraints.class}) not handled must be one of Range, Fixnum, Bignum, Infinity(n)")
    end
  end # module Associations
end # module DataMapper
