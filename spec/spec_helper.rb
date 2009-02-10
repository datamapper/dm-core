require 'rubygems'
gem 'rspec', '>=1.1.8'
require 'spec'
require 'pathname'

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path
$LOAD_PATH << SPEC_ROOT.parent + "lib"
require 'dm-core'

Pathname.glob((SPEC_ROOT + '{lib,*/shared}/**/*.rb').to_s).each { |f| require f }

# create sqlite3_fs directory if it doesn't exist
temp_db_dir = SPEC_ROOT.join('db')
temp_db_dir.mkpath

ENV['ADAPTERS'] ||= 'in_memory'

HAS_DO = DataMapper::Adapters.const_defined?('DataObjectsAdapter')

ADAPTERS = []

PRIMARY = {
  'in_memory'  => { :adapter => :in_memory },
  'yaml'       => "yaml://#{temp_db_dir}/primary_yaml",
  'sqlite3'    => 'sqlite3::memory:',
#  'sqlite3_fs' => "sqlite3://#{temp_db_dir}/primary.db",
  'mysql'      => 'mysql://localhost/dm_core_test',
  'postgres'   => 'postgres://postgres@localhost/dm_core_test'
}

ALTERNATE = {
  'in_memory'  => { :adapter => :in_memory },
  'yaml'       => "yaml://#{temp_db_dir}/secondary_yaml",
  'sqlite3'    => "sqlite3://#{temp_db_dir}/alternate.db",  # use a FS for the alternate because there can only be one memory db at a time in SQLite3
#  'sqlite3_fs' => "sqlite3://#{temp_db_dir}/alternate.db",
  'mysql'      => 'mysql://localhost/dm_core_test2',
  'postgres'   => 'postgres://postgres@localhost/dm_core_test2'
}

# These environment variables will override the default connection string:
#   MYSQL_SPEC_URI
#   POSTGRES_SPEC_URI
#   SQLITE3_SPEC_URI
#
# For example, in the bash shell, you might use:
#   export MYSQL_SPEC_URI="mysql://localhost/dm_core_test?socket=/opt/local/var/run/mysql5/mysqld.sock"

adapters = ENV['ADAPTERS'].split(' ').map { |a| a.strip.downcase }.uniq
adapters = PRIMARY.keys if adapters.include?('all')

PRIMARY.only(*adapters).each do |name, default|
  connection_string = ENV["#{name.upcase}_SPEC_URI"] || default
  begin
    adapter = DataMapper.setup(name.to_sym, connection_string)

    # test the connection if possible
    if adapter.respond_to?(:query)
      adapter.query('SELECT 1')
    end

    ADAPTERS << name
    PRIMARY[name] = connection_string  # ensure *_SPEC_URI is saved
  rescue Exception => e
    puts "Could not connect to the database using #{connection_string.inspect} because: #{e.inspect}", e.backtrace
  end
end

ADAPTERS.freeze
PRIMARY.freeze

DataMapper::Logger.new(nil, :debug)

Spec::Runner.configure do |config|
  config.extend(DataMapper::Spec::AdapterHelpers)
  config.include(DataMapper::Spec::PendingHelpers)
  config.after(:each) do
    # clear out models
    descendants = DataMapper::Model.descendants.dup.to_a
    while model = descendants.shift
      descendants.concat(model.descendants) if model.respond_to?(:descendants)
      Object.send(:remove_const, model.name.to_sym)
      DataMapper::Model.descendants.delete(model)
    end
  end
end
