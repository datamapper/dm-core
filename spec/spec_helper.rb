require 'rubygems'
gem 'rspec', '>=1.1.8'
require 'spec'
require 'pathname'

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path
require SPEC_ROOT.parent + 'lib/dm-core'
require File.join(SPEC_ROOT, "/lib/adapter_helpers")

# create sqlite3_fs directory if it doesn't exist
SPEC_ROOT.join('db').mkpath

ENV['ADAPTERS'] ||= 'in_memory'

HAS_DO   = DataMapper::Adapters.const_defined?('DataObjectsAdapter')

ADAPTERS = []

PRIMARY = {
  'in_memory'  => { :adapter => :in_memory },
  'sqlite3'    => 'sqlite3::memory:',
  'sqlite3_fs' => "sqlite3://#{SPEC_ROOT}/db/primary.db",
  'mysql'      => 'mysql://localhost/dm_core_test',
  'postgres'   => 'postgres://postgres@localhost/dm_core_test'
}

ALTERNATE = {
  'in_memory'  => 'sqlite3::memory:',
  'sqlite3'    => "sqlite3://#{SPEC_ROOT}/db/alternate.db",
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

if ENV['ADAPTERS'].strip.upcase == 'ALL'
  # If the specs are set to run with all the adapters, then let's loop
  # through everything and see which adapters are available
  PRIMARY.each do |adapter, default|
    connection_string = ENV["#{adapter.to_s.upcase}_SPEC_URI"] || default
    begin
      DataMapper.setup(adapter.to_sym, connection_string)
      ADAPTERS << adapter
    rescue Exception => e
      # nothing here
    end
  end
else
  ADAPTERS.concat ENV['ADAPTERS'].split(/\s+/).map{ |a| a.strip }
end

DataMapper::Logger.new(nil, :debug)

Spec::Runner.configure do |config|
  config.include(DataMapper::Spec)
  config.after(:each) do
    DataMapper::Resource.descendants.clear
  end
end
