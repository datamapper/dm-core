module DataMapper
  module Adapters
    class AbstractAdapter
      include Extlib::Assertions

      attr_reader :name, :uri, :options
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

      def normalize_uri(uri)
        uri.is_a?(String) ? Addressable::URI.parse(uri) : uri
      end

      private

      # Instantiate an Adapter by passing it a DataMapper::Repository
      # connection string for configuration.
      def initialize(name, uri_or_options)
        assert_kind_of 'name',           name,           Symbol
        assert_kind_of 'uri_or_options', uri_or_options, Addressable::URI, Hash, String

        @name = name

        if uri_or_options.is_a?(Hash)
          @options = Mash.new(uri_or_options)
          @uri     = Addressable::URI.new(@options)
          # URI.new doesn't import unknown keys as query values, so add them manually
          @uri.query_values = options_to_query_values || {}
        else
          @uri     = normalize_uri(uri_or_options)
          @options = Mash.new(@uri.to_hash).merge(@uri.query_values || {})
        end

        @resource_naming_convention = NamingConventions::Resource::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Field::Underscored
      end

      # Converts the options has into a uri by removing the keys
      # that would already be imported by URI.new, and converting 
      # the pairs left to strings so #query_values can grok it
      def options_to_query_values
        @options.reject { |key, v|
          URI_COMPONENTS.include? key.to_sym
        }.inject({}) { |acc, pair|
          key, val = pair
          acc[key.to_s] = val.to_s
          acc
        }
      end

      URI_COMPONENTS = [:scheme, :authority, :user, :password, :host, :port, :path, :fragment, :query].freeze
    end # class AbstractAdapter
  end # module Adapters
end # module DataMapper
