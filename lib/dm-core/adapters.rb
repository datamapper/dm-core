module DataMapper
  module Adapters
    extend Chainable
    extend Extlib::Assertions

    # Set up an adapter for a storage engine
    #
    # @see DataMapper.setup
    #
    # @api private
    def self.new(repository_name, options)
      options = normalize_options(options)
      adapter_class(options[:adapter]).new(repository_name, options)
    end

    class << self
      private

      # Normalize the arguments passed to new()
      #
      # Turns options hash or connection URI into the options hash used
      # by the adapter.
      #
      # @param [Hash, Addressable::URI, String] options
      #   the options to be normalized
      #
      # @return [Mash]
      #   the options normalized as a Mash
      #
      # @api private
      def normalize_options(options)
        case options
          when Hash             then normalize_options_hash(options)
          when Addressable::URI then normalize_options_uri(options)
          when String           then normalize_options_string(options)
          else
            assert_kind_of 'options', options, Hash, Addressable::URI, String
        end
      end

      # Normalize Hash options into a Mash
      #
      # @param [Hash] hash
      #   the hash to be normalized
      #
      # @return [Mash]
      #   the options normalized as a Mash
      #
      # @api private
      def normalize_options_hash(hash)
        hash.to_mash
      end

      # Normalize Addressable::URI options into a Mash
      #
      # @param [Addressable::URI] uri
      #   the uri to be normalized
      #
      # @return [Mash]
      #   the options normalized as a Mash
      #
      # @api private
      def normalize_options_uri(uri)
        options = normalize_options_hash(uri.to_hash)

        # Extract the name/value pairs from the query portion of the
        # connection uri, and set them as options directly.
        if options[:query]
          options.update(uri.query_values)
        end

        options[:adapter] = options[:scheme]

        options
      end

      # Normalize String options into a Mash
      #
      # @param [String] string
      #   the string to be normalized
      #
      # @return [Mash]
      #   the options normalized as a Mash
      #
      # @api private
      def normalize_options_string(string)
        normalize_options_uri(Addressable::URI.parse(string))
      end

      # Return the adapter class constant
      #
      # @param [Symbol] name
      #   the name of the adapter
      #
      # @return [Class]
      #   the AbstractAdapter subclass
      #
      # @api private
      def adapter_class(name)
        class_name = (Extlib::Inflection.camelize(name) << 'Adapter').to_sym
        load_adapter(name) unless const_defined?(class_name)
        const_get(class_name)
      end

      # Require the adapter library
      #
      # @param [String, Symbol] name
      #   the name of the adapter
      #
      # @return [Boolean]
      #   true if the adapter is loaded
      #
      # @api private
      def load_adapter(name)
        assert_kind_of 'name', name, String, Symbol

        lib  = "#{name}_adapter"
        file = DataMapper.root / 'lib' / 'dm-core' / 'adapters' / "#{lib}.rb"

        if file.file?
          require file
        else
          require lib
        end
      end
    end

    extendable do
      # @api private
      def const_added(const_name)
      end
    end
  end # module Adapters
end # module DataMapper
