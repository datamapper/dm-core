require 'benchmark'
require 'dm-migrations'

module DataMapper
  module Spec
    module AdapterHelpers

      def self.temp_db_dir=(path)
        @tmp_db_dir = Pathname(path)
      end

      def self.temp_db_dir
        @tmp_db_dir
      end


      def self.primary_adapters=(adapters_hash)
        @primary_adapters = adapters_hash
      end

      def self.primary_adapters
        @primary_adapters ||= {
          'in_memory'  => { :adapter => :in_memory },
          'yaml'       => "yaml://#{temp_db_dir}/primary_yaml",
          'sqlite3'    => 'sqlite3::memory:',
        #  'sqlite3_fs' => "sqlite3://#{temp_db_dir}/primary.db",
          'mysql'      => 'mysql://localhost/dm_core_test',
          'postgres'   => 'postgres://localhost/dm_core_test',
          'oracle'     => 'oracle://dm_core_test:dm_core_test@localhost/orcl',
          'sqlserver'  => 'sqlserver://dm_core_test:dm_core_test@localhost/dm_core_test;instance=SQLEXPRESS'
        }
      end


      def self.alternate_adapters=(adapters_hash)
        @alternate_adapters = adapters_hash
      end

      def self.alternate_adapters
        @alternate_adapters ||= {
          'in_memory'  => { :adapter => :in_memory },
          'yaml'       => "yaml://#{temp_db_dir}/secondary_yaml",
          # use a FS for the alternate because there can only be one memory db at a time in SQLite3
          'sqlite3'    => "sqlite3://#{temp_db_dir}/alternate.db",
        #  'sqlite3_fs' => "sqlite3://#{temp_db_dir}/alternate.db",
          'mysql'      => 'mysql://localhost/dm_core_test2',
          'postgres'   => 'postgres://localhost/dm_core_test2',
          'oracle'     => 'oracle://dm_core_test2:dm_core_test2@localhost/orcl',
          'sqlserver'  => 'sqlserver://dm_core_test:dm_core_test@localhost/dm_core_test2;instance=SQLEXPRESS'
        }
      end


      def self.current_adapters
        @current_adapters ||= []
      end

      def self.available_adapters
        @available_adapters ||= []
      end

      # These environment variables will override the default connection string:
      #   MYSQL_SPEC_URI
      #   POSTGRES_SPEC_URI
      #   SQLITE3_SPEC_URI
      #
      # For example, in the bash shell, you might use:
      #   export MYSQL_SPEC_URI="mysql://localhost/dm_core_test?socket=/opt/local/var/run/mysql5/mysqld.sock"
      def self.setup_adapters(adapters)
        AdapterHelpers.primary_adapters.only(*adapters).each do |name, default|
          connection_string = ENV["#{name.upcase}_SPEC_URI"] || default
          begin
            adapter = DataMapper.setup(name.to_sym, connection_string)

            # test the connection if possible
            if adapter.respond_to?(:query)
              name == 'oracle' ? adapter.select('SELECT 1 FROM dual') : adapter.select('SELECT 1')
            end

            AdapterHelpers.available_adapters << name
            AdapterHelpers.primary_adapters[name] = connection_string  # ensure *_SPEC_URI is saved
           rescue Exception => exception
             puts "Could not connect to the database using #{connection_string.inspect} because: #{exception.inspect}"
          end
        end

        # speed up test execution on Oracle
        if defined?(DataMapper::Adapters::OracleAdapter)
          DataMapper::Adapters::OracleAdapter.instance_eval do
            auto_migrate_with :delete           # table data will be deleted instead of dropping and creating table
            auto_migrate_reset_sequences false  # primary key sequences will not be reset
          end
        end
      end

      def supported_by(*adapters, &block)
        adapters = get_adapters(*adapters)

        AdapterHelpers.primary_adapters.only(*adapters).each do |adapter, connection_uri|
          # keep track of the current adapters
          AdapterHelpers.current_adapters << adapters

          describe("with #{adapter}") do
            before :all do
              # store these in instance vars for the shared adapter specs
              @adapter    = DataMapper.setup(:default, connection_uri)
              @repository = DataMapper.repository(@adapter.name)

              # create all tables and constraints before each spec
              if @repository.respond_to?(:auto_migrate!)
                @repository.auto_migrate!
              end
            end

            after :all do
              # remove all tables and constraints after each spec
              if DataMapper.respond_to?(:auto_migrate_down!, true)
                DataMapper.send(:auto_migrate_down!, @repository.name)
              end

              DataMapper::Repository.adapters.delete(@repository.name)
            end

            # TODO: add destroy_model_storage and migrations code
            # that removes the YAML file and remove this code
            after :all do
              if defined?(DataMapper::Adapters::YamlAdapter) && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)
                descendants = DataMapper::Model.descendants.to_a
                while model = descendants.shift
                  descendants.concat(model.descendants.to_a - [ model ])

                  model.default_scope.clear
                  model.all(:repository => @repository).destroy!
                end
              end
            end

            instance_eval(&block)
          end

          AdapterHelpers.current_adapters.pop
        end
      end

      def with_alternate_adapter(&block)
        adapters = AdapterHelpers.current_adapters.last

        AdapterHelpers.alternate_adapters.only(*adapters).each do |adapter, connection_uri|
          describe("and #{adapter}") do
            before :all do
              @alternate_adapter    = DataMapper.setup(:alternate, connection_uri)
              @alternate_repository = DataMapper.repository(@alternate_adapter.name)

              # create all tables and constraints before each spec
              if @alternate_repository.respond_to?(:auto_migrate!)
                @alternate_repository.auto_migrate!
              end
            end

            after :all do
              # remove all tables and constraints after each spec
              if DataMapper.respond_to?(:auto_migrate_down!, true)
                DataMapper.send(:auto_migrate_down!, @alternate_repository.name)
              end

              DataMapper::Repository.adapters.delete(@alternate_repository.name)
            end

            # TODO: add destroy_model_storage and migrations code
            # that removes the YAML file and remove this code
            after :all do
              if defined?(DataMapper::Adapters::YamlAdapter) && @alternate_adapter.kind_of?(DataMapper::Adapters::YamlAdapter)
                descendants = DataMapper::Model.descendants.to_a
                while model = descendants.shift
                  descendants.concat(model.descendants.to_a - [ model ])

                  model.default_scope.clear
                  model.all(:repository => @alternate_repository).destroy!
                end
              end
            end

            instance_eval(&block)
          end
        end
      end

      def get_adapters(*adapters)
        adapters.map! { |adapter_name| adapter_name.to_s }
        adapters = AdapterHelpers.available_adapters if adapters.include?('all')
        AdapterHelpers.available_adapters & adapters
      end

    end
  end
end
