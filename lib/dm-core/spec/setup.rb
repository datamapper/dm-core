require 'dm-core'

module DataMapper
  module Spec

    class << self

      def root
        @root ||= default_root
      end

      def root=(path)
        @root = Pathname(path)
      end

      %w[setup setup! adapter adapter_name].each do |action|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{action}(kind = :default)
            perform_action(kind, :#{action})
          end
        RUBY
      end

      def configure
        @configured = begin
          setup_logger
          require_plugins
          require_spec_adapter
          true
        end
      end

      def configured?
        @configured
      end

      def setup_logger
        if log = ENV['LOG']
          logger = DataMapper::Logger.new(log_stream(log), :debug)
          logger.auto_flush = true
        end
      end

      def require_spec_adapter
        desired_adapter = ENV['ADAPTER']
        if desired_adapter.nil? || desired_adapter == 'in_memory'
          ENV['ADAPTER_SUPPORTS'] = 'all'
          Adapters.use(Adapters::InMemoryAdapter)
        else
          require "dm-#{desired_adapter}-adapter/spec/setup"
        end
      end

      def require_plugins
        plugins = ENV['PLUGINS'] || ENV['PLUGIN']
        plugins = plugins.to_s.split(/[,\s]+/)
        unless ENV['ADAPTER'] == 'in_memory'
          plugins.push('dm-migrations')
        end
        plugins.uniq.each { |plugin| require plugin }
      end

      def spec_adapters
        @spec_adapters ||= {}
      end

    private

      def perform_action(kind, action)
        configure unless configured?
        spec_adapters[kind].send(action)
      end

      def default_root
        Pathname(Dir.pwd).join('spec')
      end

      def log_stream(log)
        log == 'file' ? root.join('log/dm.log') : $stdout
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
          @adapter ||= setup!
        end

        alias_method :setup, :adapter

        def setup!
          adapter = DataMapper.setup(name, connection_uri)
          test_connection(adapter)
          adapter
        rescue Exception => e
          puts "Could not connect to the database using '#{connection_uri}' because of: #{e.inspect}"
        end

        def adapter_name
          @adapter_name ||= infer_adapter_name
        end

        def connection_uri
          "#{adapter_name}://#{username}%s@#{host}/#{storage_name}".tap do |s|
            return s % ((password.empty?) ? "" : ":#{password}")
          end
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
          ENV.fetch('DM_DB_USER', 'datamapper')
        end

        def password
          ENV.fetch('DM_DB_PASSWORD', 'datamapper')
        end

        def host
          ENV.fetch('DM_DB_HOST', 'localhost')
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

        def infer_adapter_name
          demodulized = DataMapper::Inflector.demodulize(self.class.name.chomp('Adapter'))
          DataMapper::Inflector.underscore(demodulized).freeze
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
