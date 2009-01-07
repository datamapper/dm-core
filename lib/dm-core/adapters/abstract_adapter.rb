module DataMapper
  module Adapters
    class AbstractAdapter
      include Extlib::Assertions

      attr_reader :name, :uri
      attr_accessor :resource_naming_convention, :field_naming_convention

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

      def normalize_uri(uri_or_options)
        uri_or_options
      end

      private

      # Instantiate an Adapter by passing it a DataMapper::Repository
      # connection string for configuration.
      def initialize(name, uri_or_options)
        assert_kind_of 'name',           name,           Symbol
        assert_kind_of 'uri_or_options', uri_or_options, Addressable::URI, Hash, String #, DataObjects::URI

        @name = name
        @uri  = normalize_uri(uri_or_options)

        @resource_naming_convention = NamingConventions::Resource::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Field::Underscored

        @transactions = {}
      end

      # TODO: move to dm-more/dm-migrations
      module Migration
        ##
        # Returns whether the storage_name exists.
        #
        # @param [String] storage_name
        #   a String defining the name of a storage, for example a table name.
        #
        # @return [TrueClass, FalseClass]
        #   true if the storage exists
        #
        # TODO: move to dm-more/dm-migrations (if possible)
        def storage_exists?(storage_name)
          raise NotImplementedError
        end

        ##
        # Returns whether the field exists.
        #
        # @param [String] storage_name
        #   a String defining the name of a storage, for example a table name.
        # @param [String] field_name
        #   a String defining the name of a field, for example a column name.
        #
        # @return [TrueClass, FalseClass]
        #   true if the field exists.
        #
        # TODO: move to dm-more/dm-migrations (if possible)
        def field_exists?(storage_name, field_name)
          raise NotImplementedError
        end

        # TODO: move to dm-more/dm-migrations
        def upgrade_model_storage(repository, model)
          raise NotImplementedError
        end

        # TODO: move to dm-more/dm-migrations
        def create_model_storage(repository, model)
          raise NotImplementedError
        end

        # TODO: move to dm-more/dm-migrations
        def destroy_model_storage(repository, model)
          raise NotImplementedError
        end

        # TODO: move to dm-more/dm-migrations
        def alter_model_storage(repository, *args)
          raise NotImplementedError
        end

        # TODO: move to dm-more/dm-migrations
        def create_property_storage(repository, property)
          raise NotImplementedError
        end

        # TODO: move to dm-more/dm-migrations
        def destroy_property_storage(repository, property)
          raise NotImplementedError
        end

        # TODO: move to dm-more/dm-migrations
        def alter_property_storage(repository, *args)
          raise NotImplementedError
        end
      end

      include Migration
    end # class AbstractAdapter
  end # module Adapters
end # module DataMapper
