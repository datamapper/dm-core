require 'rubygems'
gem 'rspec', '>=1.1.8'
require 'spec'
require 'pathname'

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path
require SPEC_ROOT.parent + 'lib/dm-core'
Pathname.glob(SPEC_ROOT + '{lib,*/shared}/**/*.rb').each { |f| require f }

# create sqlite3_fs directory if it doesn't exist
SPEC_ROOT.join('db').mkpath

ENV['ADAPTERS'] ||= 'in_memory'

HAS_DO = DataMapper::Adapters.const_defined?('DataObjectsAdapter')

ADAPTERS = []

PRIMARY = {
  'in_memory'  => { :adapter => :in_memory },
  'sqlite3'    => 'sqlite3::memory:',
  'sqlite3_fs' => "sqlite3://#{SPEC_ROOT}/db/primary.db",
  'mysql'      => 'mysql://localhost/dm_core_test',
  'postgres'   => 'postgres://postgres@localhost/dm_core_test'
}

ALTERNATE = {
  'in_memory'  => { :adapter => :in_memory },
  'sqlite3'    => { :adapter => :in_memory },  # use an in-memory DB for the alternate because SQLite3 cannot have more than one in-memory DB at once
  'sqlite3_fs' => "sqlite3://#{SPEC_ROOT}/db/secondary.db",
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

PRIMARY.only(*adapters).each do |adapter, default|
  connection_string = ENV["#{adapter.upcase}_SPEC_URI"] || default
  begin
    DataMapper.setup(adapter.to_sym, connection_string)
    ADAPTERS << adapter
    PRIMARY[adapter] = connection_string  # ensure *_SPEC_URI is saved
  rescue Exception => e
    puts "Could not connect to the database using #{connection_string}"
  end
end

ADAPTERS.freeze
PRIMARY.freeze

DataMapper::Logger.new(nil, :debug)

Spec::Runner.configure do |config|
  config.extend(DataMapper::Spec::AdapterHelpers)
  config.include(DataMapper::Spec::PendingHelpers)
  config.after(:each) do
    DataMapper::Resource.descendants.clear
  end
end
