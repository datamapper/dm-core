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

      def initialize_identity_field(resource, next_id)
        if identity_field = resource.model.identity_field(name)
          identity_field.set!(resource, next_id)
          # TODO: replace above with this, once
          # specs can handle random, non-sequential ids
          #identity_field.set!(resource, rand(2**32))
        end
      end

      def attributes_as_fields(attributes)
        attributes.map { |p, v| [ p.field, v ] }.to_hash
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
