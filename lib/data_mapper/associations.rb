require __DIR__ + 'associations/many_to_one'
require __DIR__ + 'associations/one_to_many'
require __DIR__ + 'associations/many_to_many'
require __DIR__ + 'associations/one_to_one'

module DataMapper
  module Associations
    def relationships
      @relationships ||= {}
    end

    def self.extended(base)
      base.send(:extend, ManyToOne)
      base.send(:extend, OneToMany)
      base.send(:extend, ManyToMany)
      base.send(:extend, OneToOne)
    end

    def n
      1.0/0
    end

    def has(name, cardinality, options = {})
      case cardinality
        when Range then
          if cardinality.first == 0
            if cardinality.last == (1.0/0)
              one_to_many(name, options)
            else
              one_to_many(name, options.merge(:max => cardinality.last))
            end
          elsif cardinality.first == (1.0/0)
            many_to_many(name, options)
          end
        when Fixnum then one_to_one(name, options)
      end
    end
  end # module Associations
end # module DataMapper
