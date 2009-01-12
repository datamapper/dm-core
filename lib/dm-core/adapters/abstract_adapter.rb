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
        assert_kind_of 'uri_or_options', uri_or_options, Addressable::URI, Hash, String

        @name = name
        @uri  = normalize_uri(uri_or_options)

        @resource_naming_convention = NamingConventions::Resource::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Field::Underscored
      end
    end # class AbstractAdapter
  end # module Adapters
end # module DataMapper
