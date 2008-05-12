require 'rubygems'
gem 'rspec', '>=1.1.3'
require 'spec'
require 'pathname'

require Pathname(__FILE__).dirname.expand_path.parent + 'lib/data_mapper'
require DataMapper.root / 'spec' / 'lib' / 'mock_adapter'

# setup mock adapters
[ :default, :mock, :legacy, :west_coast, :east_coast ].each do |repository_name|
  DataMapper.setup(repository_name, "mock://localhost/#{repository_name}")
end

HAS_SQLITE3 = begin
  gem 'do_sqlite3', '=0.9.0'
  require 'do_sqlite3'
  DataMapper.setup(:sqlite3, ENV['SQLITE3_SPEC_URI'] || 'sqlite3::memory:')
  true
rescue Gem::LoadError
  warn "Could not load do_sqlite3: #{$!}"
  false
end

HAS_MYSQL = begin
  gem 'do_mysql', '=0.9.0'
  require 'do_mysql'
  DataMapper.setup(:mysql, ENV['MYSQL_SPEC_URI'] || 'mysql://localhost/dm_core_test')
  true
rescue Gem::LoadError
  warn "Could not load do_mysql: #{$!}"
  false
end

HAS_POSTGRES = begin
  gem 'do_postgres', '=0.9.0'
  require 'do_postgres'
  DataMapper.setup(:postgres, ENV['POSTGRES_SPEC_URI'] || 'postgres://postgres@localhost/dm_core_test')
  true
rescue Gem::LoadError
  warn "Could not load do_postgres: #{$!}"
  false
end

class Article
  include DataMapper::Resource

  property :id,         Fixnum, :serial => true
  property :blog_id,    Fixnum
  property :created_at, DateTime
  property :author,     String
  property :title,      String
end

class Comment
  include DataMapper::Resource
end

class NormalClass
  # should not include DataMapper::Resource
end

# ==========================
# Used for Association specs
class Vehicle
  include DataMapper::Resource

  property :id, Fixnum, :serial => true
  property :name, String
end

class Manufacturer
  include DataMapper::Resource

  property :id, Fixnum, :serial => true
  property :name, String
end

class Supplier
  include DataMapper::Resource

  property :id, Fixnum, :serial => true
  property :name, String
end

class Class
  def publicize_methods
    klass = class << self; self; end

    saved_private_class_methods      = klass.private_instance_methods
    saved_protected_class_methods    = klass.protected_instance_methods
    saved_private_instance_methods   = self.private_instance_methods
    saved_protected_instance_methods = self.protected_instance_methods

    self.class_eval do
      klass.send(:public, *saved_private_class_methods)
      klass.send(:public, *saved_protected_class_methods)
      public(*saved_private_instance_methods)
      public(*saved_protected_instance_methods)
    end

    begin
      yield
    ensure
      self.class_eval do
        klass.send(:private, *saved_private_class_methods)
        klass.send(:protected, *saved_protected_class_methods)
        private(*saved_private_instance_methods)
        protected(*saved_protected_instance_methods)
      end
    end
  end
end
