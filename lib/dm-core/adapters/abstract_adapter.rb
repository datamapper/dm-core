module DataMapper
  module Adapters
    # Specific adapters extend this class and implement
    # methods for creating, reading, updating and deleting records.
    #
    # Adapters may only implement method for reading or (less common case)
    # writing. Read only adapter may be useful when one needs to work
    # with legacy data that should not be changed or web services that
    # only provide read access to data (from Wordnet and Medline to
    # Atom and RSS syndication feeds)
    #
    # Note that in case of adapters to relational databases it makes
    # sense to inherit from DataObjectsAdapter class.
    class AbstractAdapter
      include Extlib::Assertions
      extend Extlib::Assertions

      # Adapter name. Note that when you use
      #
      # DataMapper.setup(:default, "postgres://postgres@localhost/dm_core_test")
      #
      # then adapter name is currently be set to is :default
      #
      # @api semipublic
      attr_reader :name

      # Options with which adapter was set up
      #
      # @api semipublic
      attr_reader :options

      # A callable object that implements naming
      # convention for resources and storages
      #
      # @api semipublic
      attr_accessor :resource_naming_convention

      # A callable object that implements naming
      # convention for properties and storage fields
      #
      # @api semipublic
      attr_accessor :field_naming_convention

      # Persists one or many new resources
      # Adapters provide specific implementation of this method
      #
      # @param [Enumerable(Resource)] resources
      #   The list of resources (model instances) to create
      #
      # @return [Integer]
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        raise NotImplementedError
      end

      # Reads one or many resources from storage
      # Adapters provide specific implementation of this method
      #
      # @api semipublic
      def read(query)
        raise NotImplementedError
      end

      # Updates one or many existing resources
      # Adapters provide specific implementation of this method
      #
      # @param [Hash(Property => Object)] attributes
      #   hash of attribute values to set, keyed by Property
      # @param [Collection] collection
      #   collection of records to be updated
      #
      # @return [Integer]
      #   the number of records updated
      #
      # @api semipublic
      def update(attributes, collection)
        raise NotImplementedError
      end

      # Deletes one or many existing resources
      # Adapters provide specific implementation of this method
      #
      # @param [Collection] collection
      #   collection of records to be deleted
      #
      # @return [Integer]
      #   the number of records deleted
      #
      # @api semipublic
      def delete(collection)
        raise NotImplementedError
      end

      protected

      ##
      # Takes an Array of records, and destructively filters it
      # by a query. First finds all matching conditions, then sorts it,
      # then does offset & limit
      #
      # @param [Array] records
      #   The set of records to be filtered
      #
      # @param [Query] query
      #   The query used to perform the filtering
      #
      # @return [Array]
      #   Whats left of the given array after the filtering
      #
      # @api semipublic
      def filter_records(records, query)
        match_records(records, query)
        sort_records(records, query)
        limit_records(records, query)
        records
      end

      ##
      # Filter a set of records by a set of conditions in a query
      #
      # @param [Array] records
      #   The set of records to be filtered
      #
      # @param [Query] query
      #   The query containing the conditions to match on
      #
      # @return [Array]
      #   Whats left of the given array after the matching
      #
      # @api semipublic
      def match_records(records, query)
        conditions = query.conditions

        # Be destructive by using #delete_if
        records.delete_if do |record|
          not conditions.matches?(record)
        end

        records
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
      # Sorts a list of Records by a given query
      #
      # @param [Enumerable] records
      #   A list of Resources to sort
      # @param [Query] query
      #   A query that contains one or more properties and
      #   directions to sort by.
      #
      # @return [Enumerable]
      #   The sorted records
      #
      # @api semipublic
      def sort_records(records, query)
        if order = query.order
          sort_order = order.map { |i| [ i.property, i.direction == :desc ] }

          # sort resources by each property
          records.sort! do |a,b|
            cmp = 0
            sort_order.each do |(property,descending)|
              cmp = a[property.field] <=> b[property.field]
              cmp *= -1 if descending
              break if cmp != 0
            end
            cmp
          end
        end
      end

      ##
      # Limits a set of records by an offset and/or limit in a query
      #
      # @param [Enumerable] records
      #   A list of Recrods to sort
      # @param [Query] query
      #   A query that contains the offset and limit
      #
      # @return [Enumerable]
      #   The offset & limited records
      #
      # @api semipublic
      def limit_records(records, query)
        offset = query.offset
        limit  = query.limit
        size   = records.size

        if offset > size - 1
          records.clear
        elsif (limit && limit != size) || offset > 0
          records.replace(records[offset, limit || size] || [])
        end
      end

      def initialize_identity_field(resource, next_id)
        if identity_field = resource.model.identity_field(name)
          identity_field.set!(resource, next_id)
          # TODO: replace above with this, once
          # specs can handle random, non-sequential ids
          #identity_field.set!(resource, rand(2**32))
        end
      end

      def attributes_as_fields(attributes)
        attributes.map { |p,v| [p.field, v] }.to_hash
      end

      private

      ##
      # Instantiate an Adapter by passing it a Repository
      # connection string for configuration.
      #
      # Also sets up default naming conventions for resources
      # and properties (fields)
      #
      # @api semipublic
      def initialize(name, options)
        assert_kind_of 'name', name, Symbol

        @name                       = name
        @options                    = options.dup.freeze
        @resource_naming_convention = NamingConventions::Resource::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Field::Underscored
      end
    end # class AbstractAdapter

    const_added(:AbstractAdapter)
  end # module Adapters
end # module DataMapper
