module DataMapper
  module Adapters
    class AbstractAdapter
      include Extlib::Assertions

      attr_reader :name, :options
      attr_accessor :resource_naming_convention, :field_naming_convention

      # Instantiate an Adapter by passing it a DataMapper::Repository
      # connection string for configuration.
      def initialize(name, uri_or_options)
        assert_kind_of 'name',           name,           Symbol
        assert_kind_of 'uri_or_options', uri_or_options, Addressable::URI, Hash, String

        @name = name

        if uri_or_options.is_a?(Hash)
          @options = Mash.new(uri_or_options)
        else
          uri      = uri_or_options.is_a?(String) ? Addressable::URI.parse(uri_or_options) : uri_or_options
          @options = uri_to_options(uri)
        end

        @resource_naming_convention = NamingConventions::Resource::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Field::Underscored
      end

      def create(resources)
        raise NotImplementedError
      end

      def read_many(query)
        raise NotImplementedError
      end

      def read_one(query)
        raise NotImplementedError
      end

      def update(attributes, query)
        raise NotImplementedError
      end

      def delete(query)
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
      # @param [DataMapper::Query] query
      #   The query used to perform the filtering
      #
      # @returns [Array]
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
      # @param [DataMapper::Query] query
      #   The query containing the conditions to match on
      #
      # @returns [Array]
      #   Whats left of the given array after the matching
      #
      # @api semipublic
      def match_records(records, query)
        conditions = query.conditions

        # Be destructive by using #delete_if
        records.delete_if do |record|
          not conditions.all? do |condition|
            operator, property, bind_value = *condition

            value = record[property.name]

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
      # @param [DataMapper::Query] query
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
              cmp = a[property.name] <=> b[property.name]
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
      # @param [DataMapper::Query] query
      #   A query that contains the offset and limit
      #
      # @return [Enumerable]
      #   The offset & limited records
      #
      # @api semipublic
      def limit_records(records, query)
        offset = query.offset
        limit  = query.limit

        size = records.size

        if offset > size - 1
          records.clear
        elsif (limit && limit != size) || offset > 0
          records.replace(records[offset, limit || size] || [])
        end
      end

      private

      def uri_to_options(uri)
        options = Mash.new(uri.to_hash).merge(uri.query_values || {})

        # Alias 'scheme' part of uri to 'adapter', if its not already set
        if options.has_key?(:scheme) && !options.has_key?(:adapter)
          options[:adapter] = options.delete(:scheme)
        end

        options
      end

    end # class AbstractAdapter
  end # module Adapters
end # module DataMapper
