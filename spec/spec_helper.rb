require 'rubygems'
gem 'rspec', '>=1.1.3'
require 'spec'
require 'pathname'

require Pathname(__FILE__).dirname.expand_path.parent + 'lib/dm-core'
require DataMapper.root / 'spec' / 'lib' / 'mock_adapter'

# setup mock adapters
[ :default, :mock, :legacy, :west_coast, :east_coast ].each do |repository_name|
  DataMapper.setup(repository_name, "mock://localhost/#{repository_name}")
end

def setup_adapter(name, default_uri)
  begin
    DataMapper.setup(name, ENV["#{name.to_s.upcase}_SPEC_URI"] || default_uri)
    Object.const_set('ADAPTER', ENV['ADAPTER'].to_sym) if name.to_s == ENV['ADAPTER']
    true
  rescue Exception => e
    if name.to_s == ENV['ADAPTER']
      Object.const_set('ADAPTER', nil)
      warn "Could not load #{name} adapter: #{e}"
    end
    false
  end
end

ENV['ADAPTER'] ||= 'sqlite3'

HAS_SQLITE3  = setup_adapter(:sqlite3,  'sqlite3::memory:')
HAS_MYSQL    = setup_adapter(:mysql,    'mysql://localhost/dm_core_test')
HAS_POSTGRES = setup_adapter(:postgres, 'postgres://postgres@localhost/dm_core_test')

DataMapper::Logger.new(nil, :debug)

class Article
  include DataMapper::Resource

  property :id,         Integer, :serial => true
  property :blog_id,    Integer
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

  property :id, Integer, :serial => true
  property :name, String

  class << self
    attr_accessor :mock_relationship
  end
end

class Manufacturer
  include DataMapper::Resource

  property :id, Integer, :serial => true
  property :name, String

  class << self
    attr_accessor :mock_relationship
  end
end

class Supplier
  include DataMapper::Resource

  property :id, Integer, :serial => true
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
