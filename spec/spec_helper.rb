require 'rubygems'
gem 'rspec', '>=1.1.3'
require 'pathname'
require 'spec'
require 'fileutils'

require Pathname(__FILE__).dirname.expand_path.parent + 'lib/data_mapper'
require DataMapper.root / 'spec' / 'lib' / 'mock_adapter'

gem 'rspec', '>=1.1.3'

INTEGRATION_DB_PATH = DataMapper.root / 'spec' / 'integration' / 'integration_test.db'

FileUtils.touch INTEGRATION_DB_PATH unless INTEGRATION_DB_PATH.exist?

DataMapper.setup(:default, 'mock://localhost')

# Determine log path.
ENV['_'] =~ /(\w+)/
log_path = DataMapper.root / 'log' / "#{$1 == 'opt' ? 'spec' : $1}.log"
log_path.dirname.mkpath

DataMapper::Logger.new(log_path, 0)
at_exit { DataMapper.logger.close }

class Article
  include DataMapper::Resource

  property :id,         Fixnum, :serial => true
  property :blog_id,    Fixnum
  property :created_at, DateTime
  property :author,     String
  property :title,      String

  class << self
    def property_by_name(name)
      properties(repository.name)[name]
    end
  end
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
