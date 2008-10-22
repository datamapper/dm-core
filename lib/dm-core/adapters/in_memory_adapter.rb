module DataMapper
  module Adapters
    # This is probably the simplest functional adapter possible. It simply
    # stores and queries from a hash containing the model classes as keys, 
    # and an array of records. It is not persitent whatsoever; when the ruby
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
      # @param [Array] resources
      #   The set of resources (model instances) 
      #
      # @return [Integer] 
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        repository_name = self.name

        resources.each do |resource|
          # TODO: make a model.identity_field method
          if identity_field = resource.model.key(repository.name).detect { |p| p.serial? }
            identity_field.set!(resource, @records[resource.model].size.succ)
          end

          @records[resource.model][resource.key] = resource.dirty_attributes.map { |p,v| [ p.field(repository_name), v ] }.to_hash
        end.size # just return the number of records
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
      # @return [Integer] the number of records that were successfully updated
      #
      # @api semipublic
      def update(attributes, query)
        repository_name = query.repository.name
        records         = @records[query.model]
        attributes      = attributes.map { |p,v| [ p.field(repository_name), v ] }.to_hash

        read_many(query).each do |resource|
          records[resource.key].update(attributes)
        end.size
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
        read(query, query.model, false)
      end

      ## 
      # Looks up a collection of records from the data-store: "SELECT" in SQL.
      # Used by Model#all to search for a set of records; that set is in a 
      # DataMapper::Collection object.
      #
      # @param [DataMapper::Query] query
      #   The query to be used to seach for the resources
      #
      # @return [DataMapper::Collection]
      #   A collection of all the resources found by the query.
      #
      # @api semipublic
      def read_many(query)
        Collection.new(query) do |set|
          read(query, set, true)
        end
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
        records = @records[query.model]

        read_many(query).each do |resource|
          records.delete(resource.key)
        end.size
      end

      private

      ##
      # Make a new instance of the adapter. The @records ivar is the 'data-store'
      # for this adapter. It is not shared amongst multiple incarnations of this
      # adapter, eg DataMapper.setup(:default, :adapter => :in_memory); 
      # DataMapper.setup(:alternate, :adapter => :in_memory) do not share the
      # data-store between them.
      #
      # @param <String, Symbol> name
      #   The name of the DataMapper::Repository using this adapter.
      # @param <String, Hash> uri_or_options
      #   The connection uri string, or a hash of options to set up 
      #   the adapter
      #
      # @api semipublic
      def initialize(name, uri_or_options)
        super
        @records = Hash.new { |hash,model| hash[model] = {} }
      end

      ##
      # #TODO: Extract this into its own module, so it can be re-used in all
      #        adapters that don't have a native query language
      #
      # This is the normal way of parsing the DataMapper::Query object into
      # a set of conditions. This particular one translates it into ruby code
      # that can be performed on ruby objects. It can be reused in most other 
      # adapters, however, if the adapter has its own native query language, 
      # such as SQL, an adapter developer is probably better using this as an 
      # example of how to parse the DataMapper::Query object.
      #
      # @api private
      def read(query, set, many = true)
        repository_name = query.repository.name
        conditions      = query.conditions

        # find all matching records
        results = @records[query.model].values.select do |attributes|
          conditions.all? do |tuple|
            operator, property, bind_value = *tuple

            value = attributes[property.field(repository_name)]

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

        # sort the results
        if query.order.any?
          results = sorted_results(results, query.order, repository_name)
        end

        # limit the results
        if query.limit || query.offset > 0
          results = results[query.offset, query.limit || results.size]
        end

        return if results.empty?

        properties = query.fields

        # load a Resource for each result
        results.each do |attributes|
          values = properties.map { |p| attributes[p.field(repository_name)] }
          many ? set.load(values) : (break set.load(values, query))
        end
      end

      # TODO: document
      # @api private
      def equality_comparison(bind_value, value)
        case bind_value
          when Array, Range then bind_value.include?(value)
          when NilClass     then value.nil?
          else                   bind_value == value
        end
      end

      # TODO: document
      # @api private
      def sorted_results(results, order, repository_name)
        # get each field and if it's sorted in descending/ascending order
        field_order = field_order(order, repository_name)

        # sort results by each field
        results.sort do |a,b|
          cmp = 0
          field_order.each do |(field,descending)|
            cmp = descending ? b[field] <=> a[field] : a[field] <=> b[field]
            next if cmp == 0
          end
          cmp
        end
      end

      # TODO: document
      # @api private
      def field_order(order, repository_name)
        order.map do |item|
          property, descending = nil, false

          case item
            when Property
              property = item
            when Query::Direction
              property  = item.property
              descending = true if item.direction == :desc
          end

          [ property.field(repository_name), descending ]
        end
      end
    end
  end
end
