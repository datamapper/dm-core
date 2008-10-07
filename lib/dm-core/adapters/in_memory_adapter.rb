module DataMapper
  module Adapters
    class InMemoryAdapter < AbstractAdapter

      def initialize(name, uri_or_options)

        @records = Hash.new { |hash,model| hash[model] = Array.new }
      end

      def create(resources)
        resources.each do |resource|
          model = resource.model
          @records[model] << resource
        end.size # just return the number of records
      end

      def update(attributes, query)
        simple_attributes = {}
        attributes.each do |k,v|
          simple_attributes[k.name.to_sym] = v
        end

        records_to_update = read(query)
        records_to_update.each do |record|
          record.attributes = simple_attributes
        end.size
      end

      def read_one(query)
        read(query).first
      end

      def read_many(query)
        read(query)
      end

      def delete(query)
        records_to_delete = read(query)

        records_to_delete.each do |r|
          @records[query.model].delete_at(@records[query.model].index(r))
        end
      end

      def read(query)
        model = query.model

        # Iterate over the records for this model, and #select
        # the ones that match the conditions
        set = @records[model].select do |r|
          boolean_and(*query.conditions.map do |c|
            val = r.attributes[c[1].name.to_sym]
            case c[0]
            when :eql
              val == c[2]
            # TODO: Things other than :eql
            end
          end)
        end

        # TODO Sort

        # TODO Limit

        set
      end

      # Returns true if every value given is true
      def boolean_and(*arr)
        arr.each do |v|
          return false unless v
        end
        true
      end
    end
  end
end
