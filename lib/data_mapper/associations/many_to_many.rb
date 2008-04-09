require __DIR__.parent + 'associations'
require __DIR__ + 'relationship'

module DataMapper
  module Associations
    module ManyToMany
      def many_to_many(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        target = options[:class_name] || DataMapper::Inflection.camelize(name)

        relationships[name] = Relationship.new(
          name,
          options[:repository_name] || repository.name,
          DataMapper::Inflection.demodulize(self.name),
          nil,
          target,
          nil
        )
      end

      class Instance
        def initialize() end

        def save
          raise NotImplementedError
        end

      end # class Instance
    end # module ManyToMany
  end # module Associations
end # module DataMapper
