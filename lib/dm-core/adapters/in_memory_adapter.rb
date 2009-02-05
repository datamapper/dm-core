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
          identity_map = identity_map(resource.model)

          if identity_field = resource.model.identity_field(name)
            identity_field.set!(resource, identity_map.size.succ)
          end

          # copy the userspace Resource so that if we call #update we
          # don't silently change the data in userspace
          identity_map[resource.key] = resource.dup
        end

        resources.size
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
        identity_map = identity_map(query.model)

        resources = read_many(query).each do |r|
          resource = identity_map[r.key]
          attributes.each { |p,v| p.set!(resource, v) }
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
        # TODO: Extract this into its own module, so it can be re-used in all
        # adapters that don't have a native query language

        model      = query.model
        fields     = query.fields
        offset     = query.offset
        limit      = query.limit
        order      = query.order

        records = identity_map(model).values

        filter_records(records, query)

        size = records.size

        # if the requested resource is outside the range of available
        # resources return
        if offset > size - 1
          return []
        end

        # sort the resources
        sort_resources( records, order)

        # limit the resources
        unless (limit.nil? || limit == size) && offset == 0
          records = records[offset, limit || size]
        end

        # copy the value from each InMemoryAdapter Resource
        records.map! do |record|
          model.load(fields.map { |p| p.get!(record) }, query)
        end
      end

      def filter_records(records, query)
        conditions = query.conditions
        records.delete_if do |record| # Be destructive by using #delete_if
          not conditions.all? do |condition|
            operator, property, bind_value = *condition

            value = property.get!(record)

            case operator
            when :eql, :in then equality_comparison(bind_value, value)
            when :not      then !equality_comparison(bind_value, value)
            when :like     then Regexp.new(bind_value) =~ value
            when :gt       then !value.nil? && value >  bind_value
            when :gte      then !value.nil? && value >= bind_value
            when :lt       then !value.nil? && value <  bind_value
            when :lte      then !value.nil? && value <= bind_value
            end
          end
        end

        records
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
        identity_map = identity_map(query.model)
        read_many(query).each { |r| identity_map.delete(r.key) }.size
      end

      private

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
        @identity_maps = {}
      end

      ##
      # Compares two values and returns true if they are equal
      #
      # @param [Object] bind_value
      #   The value we are comparing against
      # @param [Object] value
      #   The value we are comparing with
      #
      # @return [TrueClass,FalseClass]
      #   Returns true if the values are equal
      #
      # @api private
      def equality_comparison(bind_value, value)
        case bind_value
          when Array, Range then bind_value.include?(value)
          else                   bind_value == value
        end
      end

      ##
      # Sorts a list of Resources by a given order
      #
      # @param [Enumerable] resources
      #   A list of Resources to sort
      # @param [Enumerable(Query::Direction)] order
      #   A list of Direction objects specifying which property and
      #   direction to sort by.
      #
      # @return [Enumerable]
      #   The sorted Resources
      #
      # @api private
      def sort_resources(resources, order)
        sort_order = order.map { |i| [ i.property, i.direction == :desc ] }

        # sort resources by each property
        resources.sort! do |a,b|
          cmp = 0
          sort_order.each do |(property,descending)|
            cmp = property.get!(a) <=> property.get!(b)
            cmp *= -1 if descending
            break if cmp != 0
          end
          cmp
        end
      end

      ##
      # Returns the Identity Map for a given Model
      #
      # @param [DataMapper::Model] model
      #   A model to retrieve the Identity Map for
      #
      # @return [DataMapper::IdentityMap]
      #   The Identity Map of Resources
      #
      # @api private
      def identity_map(model)
        @identity_maps[model] ||= IdentityMap.new
      end
    end # class InMemoryAdapter

    const_added(:InMemoryAdapter)
  end # module Adapters
end # module DataMapper
