require 'pathname'
require 'active_support/inflector'

module DataMapper
  module Spec

    class << self

      attr_reader :root

      def root=(path)
        @root = Pathname(path)
      end

      def setup(root = default_root)
        setup_logger(root)
        require_plugins
        require_adapter
      end

      def setup_logger(root = default_root)
        self.root = root
        logger = DataMapper::Logger.new(root.join('log/dm.log'), :debug)
        logger.auto_flush = true
        logger
      end

      def require_adapter
        if ENV['ADAPTER'] == 'in_memory'
          ENV['ADAPTER_SUPPORTS'] = 'all'
          Adapters.use(Adapters::InMemoryAdapter)
        else
          require "dm-#{ENV['ADAPTER']}-adapter/spec/setup"
        end
      end

      def require_plugins
        plugins = ENV['PLUGINS'] || ENV['PLUGIN']
        plugins = plugins.to_s.split(/[,\s]+/).push('dm-migrations').uniq
        plugins.each { |plugin| require plugin }
      end

      def adapter(kind = :default)
        spec_adapters[kind].adapter
      end

      def adapter_name(kind = :default)
        spec_adapters[kind].adapter_name
      end

      def spec_adapters
        @spec_adapters ||= {}
      end

    private

      def default_root
        Pathname(caller[1]).dirname.expand_path
      end

    end

    module Adapters

      def self.use(adapter_class)
        Spec.spec_adapters[:default]   = adapter_class.new(:default)
        Spec.spec_adapters[:alternate] = adapter_class.new(:alternate)
      end

      class Adapter

        attr_reader :name

        def initialize(name)
          @name = name.to_sym
        end

        def adapter
          @adapter ||= setup
        end

        def adapter_name
          @adapter_name ||= infer_adapter_name
        end

        def connection_uri
          "#{adapter_name}://#{username}:#{password}@localhost/#{storage_name}"
        end

        def storage_name
          send("#{name}_storage_name")
        end

        def default_storage_name
          "datamapper_default_tests"
        end

        def alternate_storage_name
          "datamapper_alternate_tests"
        end

        def username
          'datamapper'
        end

        def password
          'datamapper'
        end

        # Test the connection
        #
        # Overwrite this method if you need to perform custom connection testing
        #
        # @raise [Exception]
        def test_connection(adapter)
          if adapter.respond_to?(:select)
            adapter.select('SELECT 1')
          end
        end

      private

        def setup
          adapter = DataMapper.setup(name, connection_uri)
          test_connection(adapter)
          adapter
        rescue Exception => e
          puts "Could not connect to the database using '#{connection_uri}' because of: #{e.inspect}"
        end

        def infer_adapter_name
          demodulized = ActiveSupport::Inflector.demodulize(self.class.name.chomp('Adapter'))
          ActiveSupport::Inflector.underscore(demodulized).freeze
        end

      end

      class InMemoryAdapter < Adapter
        def connection_uri
          { :adapter => :in_memory }
        end
      end

    end
  end
end
