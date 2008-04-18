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

    def has(cardinality, name, options = {})
      case cardinality
        when Range
          left, right = cardinality.first, cardinality.last
          case 1
            when left                       #1..n or 1..2
              one_to_many(name, options.merge(extract_min_max(right)))
            when right                      # n..1 or 2..1
              many_to_one(name, options.merge(extract_min_max(left)))
            else                            # n..n or 2..2
              many_to_many(name, options.merge(extract_min_max(cardinality)))
          end
        when 1
          one_to_one(name, options)
        when Fixnum, Bignum, n              # n or 2 - shorthand form of 1..n or 1..2
          one_to_many(name, options.merge(extract_min_max(cardinality)))
      end || raise(ArgumentError, "Cardinality #{cardinality.inspect} (#{cardinality.class}) not handled")
    end
    
  private 
    def extract_min_max(contraints)
      case contraints
        when Range
          left = extract_min_max(contraints.first)
          right = extract_min_max(contraints.last)
          conditions = {}
          conditions.merge!(:left=>left) if left.any?
          conditions.merge!(:right=>right) if right.any?
          conditions
        when Fixnum, Bignum
          {:min=>contraints, :max=>contraints}
        when n
          {}
      end || raise(ArgumentError, "Contraint #{contraints.inspect} (#{contraints.class}) not handled must be one of Range, Fixnum, Bignum, Infinity(n)")
    end
  end # module Associations
end # module DataMapper
