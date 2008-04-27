# This file begins the loading sequence.
#
# Quick Overview:
# * Requires set, fastthread, support libs, and base
# * Sets the applications root and environment for compatibility with rails or merb
# * Checks for the database.yml and loads it if it exists
# * Sets up the database using the config from the yaml file or from the environment
#

# Require the basics...
require 'date'
require 'pathname'
require 'rubygems'
require 'set'
require 'time'
require 'uri'
require 'yaml'

begin
  require 'fastthread'
rescue LoadError
end

# for Pathname /
require File.expand_path(File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'pathname'))

dir = Pathname(__FILE__).dirname.expand_path / 'data_mapper'

require dir / 'associations'
require dir / 'auto_migrations'
require dir / 'collection'
require dir / 'hook'
require dir / 'identity_map'
require dir / 'logger'
require dir / 'naming_conventions'
require dir / 'property_set'
require dir / 'query'
require dir / 'repository'
require dir / 'resource'
require dir / 'scope'
require dir / 'support'
require dir / 'type'
require dir / 'type_map'
require dir / 'types'
require dir / 'property'
require dir / 'adapters'

module DataMapper
  def self.root
    @root ||= Pathname(__FILE__).dirname.parent.expand_path
  end

  def self.setup(name, uri_or_options)
    raise ArgumentError, "+name+ must be a Symbol, but was #{name.class}", caller unless Symbol === name

    case uri_or_options
      when Hash
        adapter_name = uri_or_options[:adapter]
      when String, URI
        uri_or_options = URI.parse(uri_or_options) if String === uri_or_options
        adapter_name = uri_or_options.scheme
      else
        raise ArgumentError, "+uri_or_options+ must be a Hash, URI or String, but was #{uri_or_options.class}", caller
    end

    # TODO: use autoload to load the adapter on-the-fly when used
    class_name = DataMapper::Inflection.classify(adapter_name) + 'Adapter'

    unless Adapters::const_defined?(class_name)
      lib_name = "#{DataMapper::Inflection.underscore(adapter_name)}_adapter"
      begin
        require root / 'lib' / 'data_mapper' / 'adapters' / lib_name
      rescue LoadError
        require lib_name
      end
    end

    Repository.adapters[name] = Adapters::const_get(class_name).new(name, uri_or_options)
  end

  # ===Block Syntax:
  # Pushes the named repository onto the context-stack,
  # yields a new session, and pops the context-stack.
  #
  #   results = DataMapper.repository(:second_database) do |current_context|
  #     ...
  #   end
  #
  # ===Non-Block Syntax:
  # Returns the current session, or if there is none,
  # a new Session.
  #
  #   current_repository = DataMapper.repository
  def self.repository(name = nil) # :yields: current_context
    # TODO return context.last if last.name == name (arg)
    current_repository = if name
      Repository.new(name)
    else
      Repository.context.last || Repository.new(Repository.default_name)
    end

    return current_repository unless block_given?

    Repository.context << current_repository

    begin
      return yield(current_repository)
    ensure
      Repository.context.pop
    end
  end
  
  def self.migrate!(name = :default)
    repository(name).migrate!
  end
  
  def self.auto_migrate!(name = :default)
    repository(name).auto_migrate!
  end
  
  def self.prepare(name = nil, &blk)
    yield repository(name)
  end
end
