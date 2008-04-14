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

    def has(name, cardinality, options = {})
      case cardinality
        when Range
          min, max = cardinality.first, cardinality.last
          case min
            when 0, 1                   # 0..n, 1..n
              one_to_many(name, options.merge(:min => min, :max => max))
            when Fixnum, Bignum, n
              case max
                when 0, 1               # n..0, n..1
                  many_to_one(name, options.merge(:min => min, :max => max))
                when Fixnum, Bignum, n  # n..2, n..n
                  many_to_many(name, options.merge(:min => min, :max => max))
              end
          end
        when 1
          one_to_one(name, options)
        when Fixnum, Bignum, n
          one_to_many(name, options.merge(:min => cardinality, :max => cardinality))
      end || raise(ArgumentError, "Cardinality #{cardinality.inspect} (#{cardinality.class}) not handled")
    end
  end # module Associations
end # module DataMapper
