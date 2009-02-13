module DataMapper
  module Adapters
    # This is probably the simplest functional adapter possible. It simply
    # stores and queries from a hash containing the model classes as keys,
    # and an array of records. It is not persistent whatsoever; when the Ruby
    # process finishes, everything that was stored it lost. However, it doesn't
    # require any other external libraries, such as data_objects, so it is ideal
    # for writing specs against. It also serves as an excellent example for
    # budding adapter developers, so it is critical that it remains well documented
    # and up to date.
    class InMemoryAdapter < AbstractAdapter
      ##
      # Make a new instance of the adapter. The @model_records ivar is the 'data-store'
      # for this adapter. It is not shared amongst multiple incarnations of this
      # adapter, eg DataMapper.setup(:default, :adapter => :in_memory);
      # DataMapper.setup(:alternate, :adapter => :in_memory) do not share the
      # data-store between them.
      #
      # @param [String, Symbol] name
      #   The name of the DataMapper::Repository using this adapter.
      # @param [String, Hash] uri_or_options
      #   The connection uri string, or a hash of options to set up
      #   the adapter
      #
      # @api semipublic
      def initialize(name, uri_or_options)
        super
        @records = {}
      end

      ##
      # Used by DataMapper to put records into a data-store: "INSERT" in SQL-speak.
      # It takes an array of the resources (model instances) to be saved. Resources
      # each have a key that can be used to quickly look them up later without
      # searching, if the adapter supports it.
      #
      # @param [Enumerable(DataMapper::Resource)] resources
      #   The set of resources (model instances)
      #
      # @return [Integer]
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        resources.each do |resource|
          records = records_for(resource.model)

          if identity_field = resource.model.identity_field(name)
            identity_field.set!(resource, records.size.succ)
          end

          records[resource.key] = resource.attributes
        end

        resources.size
      end

      ##
      # Look up a single record from the data-store. "SELECT ... LIMIT 1" in SQL.
      # Used by Model#get to find a record by its identifier(s), and Model#first
      # to find a single record by some search query.
      #
      # @param [DataMapper::Query] query
      #   The query to be used to locate the resource.
      #
      # @return [DataMapper::Resource]
      #   A Resource object representing the record that was found, or nil for no
      #   matching records.
      #
      # @api semipublic
      def read_one(query)
        read_many(query).first
      end

      ##
      # Looks up a collection of records from the data-store: "SELECT" in SQL.
      # Used by Model#all to search for a set of records; that set is in an
      # Array object.
      #
      # @param [DataMapper::Query] query
      #   The query to be used to seach for the resources
      #
      # @return [Array]
      #   An Array of all the resources found by the query.
      #
      # @api semipublic
      def read_many(query)
        model  = query.model
        fields = query.fields

        records = records_for(model)

        filter_records(records.values, query).map! do |record|
          model.load(fields.map { |p| record[p.name] }, query)
        end
      end

      ##
      # Used by DataMapper to update the attributes on existing records in a
      # data-store: "UPDATE" in SQL-speak. It takes a hash of the attributes
      # to update with, as well as a query object that specifies which resources
      # should be updated.
      #
      # @param [Hash] attributes
      #   A set of key-value pairs of the attributes to update the resources with.
      # @param [DataMapper::Query] query
      #   The query that should be used to find the resource(s) to update.
      #
      # @return [Integer]
      #   the number of records that were successfully updated
      #
      # @api semipublic
      def update(attributes, query)
        records    = records_for(query.model)
        attributes = attributes.map { |p,v| [ p.name, v ] }.to_hash

        updated = filter_records(records.values, query)
        updated.each { |r| r.update(attributes) }
        updated.size
      end

      ##
      # Destroys all the records matching the given query. "DELETE" in SQL.
      #
      # @param [DataMapper::Query] query
      #   The query used to locate the resources to be deleted.
      #
      # @return [Integer]
      #   The number of records that were deleted.
      #
      # @api semipublic
      def delete(query)
        records = records_for(query.model)
        deleted = filter_records(records.values, query).to_set
        records.delete_if { |_k,r| deleted.include?(r) }
        deleted.size
      end

      private

      ##
      # All the records we're storing. This method will look them up by model name
      #
      # @api private
      def records_for(model)
        @records[model] ||= {}
      end

    end # class InMemoryAdapter

    const_added(:InMemoryAdapter)
  end # module Adapters
end # module DataMapper
