module DataMapper
  module Adapters
    extend Chainable
    extend DataMapper::Assertions

    # Set up an adapter for a storage engine
    #
    # @see DataMapper.setup
    #
    # @api private
    def self.new(repository_name, options)
      options = normalize_options(options)
      adapter_class(options.fetch(:adapter)).new(repository_name, options)
    end

    # The path used to require the in memory adapter
    #
    # Set this if you want to register your own adapter
    # to be used when you specify an 'in_memory' connection
    # during
    #
    # @see DataMapper.setup
    #
    # @param [String] path
    #   the path used to require the desired in memory adapter
    #
    # @api semipublic
    def self.in_memory_adapter_path=(path)
      @in_memory_adapter_path = path
    end

    # The path used to require the in memory adapter
    #
    # @see DataMapper.setup
    #
    # @return [String]
    #   the path used to require the desired in memory adapter
    #
    # @api semipublic
    def self.in_memory_adapter_path
      @in_memory_adapter_path ||= 'dm-core/adapters/in_memory_adapter'
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
        DataMapper::Ext::Hash.to_mash(hash)
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
        if options.fetch(:query)
          options.update(uri.query_values)
        end

        options[:adapter] = options.fetch(:scheme)

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
      # @example
      #   DataMapper::Adapters.send(:adapter_class, 'mysql') # => DataMapper::Adapters::MysqlAdapter
      #
      # @param [Symbol] name
      #   the name of the adapter
      #
      # @return [Class]
      #   the AbstractAdapter subclass
      #
      # @api private
      def adapter_class(name)
        adapter_name = normalize_adapter_name(name)
        class_name = (DataMapper::Inflector.camelize(adapter_name) << 'Adapter').to_sym
        load_adapter(adapter_name) unless const_defined?(class_name)
        const_get(class_name)
      end

      # Return the name of the adapter
      #
      # @example
      #   DataMapper::Adapters.adapter_name('MysqlAdapter') # => 'mysql'
      #
      # @param [String] const_name
      #   the adapter constant name
      #
      # @return [String]
      #   the name of the adapter
      #
      # @api semipublic
      def adapter_name(const_name)
        const_name.to_s.chomp('Adapter').downcase
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
        require "dm-#{name}-adapter"
      rescue LoadError => original_error
        begin
          require in_memory_adapter?(name) ? in_memory_adapter_path : legacy_path(name)
        rescue LoadError
          raise original_error
        end
      end

      # Returns wether or not the given adapter name is considered an in memory adapter
      #
      # @param [String, Symbol] name
      #   the name of the adapter
      #
      # @return [Boolean]
      #   true if the adapter is considered to be an in memory adapter
      #
      # @api private
      def in_memory_adapter?(name)
        name.to_s == 'in_memory'
      end

      # Returns the fallback filename that would be used to require the named adapter
      #
      # The fallback format is "#{name}_adapter" and will be phased out in favor of
      # the properly 'namespaced' "dm-#{name}-adapter" format.
      #
      # @param [String, Symbol] name
      #   the name of the adapter to require
      #
      # @return [String]
      #   the filename that gets required for the adapter identified by name
      #
      # @api private
      def legacy_path(name)
        "#{name}_adapter"
      end

      # Adjust the adapter name to match the name used in the gem providing the adapter
      #
      # @param [String, Symbol] name
      #   the name of the adapter
      #
      # @return [String]
      #   the normalized adapter name
      #
      # @api private
      def normalize_adapter_name(name)
        (original = name.to_s) == 'sqlite3' ? 'sqlite' : original
      end

    end

    extendable do
      # @api private
      def const_added(const_name)
      end
    end
  end # module Adapters
end # module DataMapper
