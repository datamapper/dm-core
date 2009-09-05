module DataMapper
  module Adapters
    # This is probably the simplest functional adapter possible. It simply
    # stores and queries from a hash containing the model classes as keys,
    # and an array of hashes. It is not persistent whatsoever; when the Ruby
    # process finishes, everything that was stored it lost. However, it doesn't
    # require any other external libraries, such as data_objects, so it is ideal
    # for writing specs against. It also serves as an excellent example for
    # budding adapter developers, so it is critical that it remains well documented
    # and up to date.
    class InMemoryAdapter < AbstractAdapter
      # Used by DataMapper to put records into a data-store: "INSERT" in SQL-speak.
      # It takes an array of the resources (model instances) to be saved. Resources
      # each have a key that can be used to quickly look them up later without
      # searching, if the adapter supports it.
      #
      # @param [Enumerable(Resource)] resources
      #   The set of resources (model instances)
      #
      # @api semipublic
      def create(resources)
        records = records_for(resources.first.model)

        resources.each do |resource|
          initialize_serial(resource, records.size.succ)
          records << resource.attributes(:field)
        end
      end

      # Looks up one record or a collection of records from the data-store:
      # "SELECT" in SQL.
      #
      # @param [Query] query
      #   The query to be used to seach for the resources
      #
      # @return [Array]
      #   An Array of Hashes containing the key-value pairs for
      #   each record
      #
      # @api semipublic
      def read(query)
        query.filter_records(records_for(query.model).dup)
      end

      # Used by DataMapper to update the attributes on existing records in a
      # data-store: "UPDATE" in SQL-speak. It takes a hash of the attributes
      # to update with, as well as a collection object that specifies which resources
      # should be updated.
      #
      # @param [Hash] attributes
      #   A set of key-value pairs of the attributes to update the resources with.
      # @param [DataMapper::Collection] resources
      #   The collection of resources to update.
      #
      # @api semipublic
      def update(attributes, collection)
        attributes = attributes_as_fields(attributes)
        read(collection.query).each { |resource| resource.update(attributes) }.size
      end

      # Destroys all the records matching the given query. "DELETE" in SQL.
      #
      # @param [DataMapper::Collection] resources
      #   The collection of resources to delete.
      #
      # @return [Integer]
      #   The number of records that were deleted.
      #
      # @api semipublic
      def delete(collection)
        records = records_for(collection.model)
        records_to_delete = collection.query.filter_records(records.dup)
        records.replace(records - records_to_delete)
        records_to_delete.size
      end

      private

      # Make a new instance of the adapter. The @records ivar is the 'data-store'
      # for this adapter. It is not shared amongst multiple incarnations of this
      # adapter, eg DataMapper.setup(:default, :adapter => :in_memory);
      # DataMapper.setup(:alternate, :adapter => :in_memory) do not share the
      # data-store between them.
      #
      # @param [String, Symbol] name
      #   The name of the Repository using this adapter.
      # @param [String, Hash] uri_or_options
      #   The connection uri string, or a hash of options to set up
      #   the adapter
      #
      # @api semipublic
      def initialize(name, options = {})
        super
        @records = {}
      end

      # All the records we're storing. This method will look them up by model name
      #
      # @api private
      def records_for(model)
        @records[model.storage_name(name)] ||= []
      end

    end # class InMemoryAdapter

    const_added(:InMemoryAdapter)
  end # module Adapters
end # module DataMapper
