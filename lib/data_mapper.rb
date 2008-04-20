# This file begins the loading sequence.
#
# Quick Overview:
# * Requires set, fastthread, support libs, and base
# * Sets the applications root and environment for compatibility with rails or merb
# * Checks for the database.yml and loads it if it exists
# * Sets up the database using the config from the yaml file or from the environment
#

# Require the basics...
require 'pathname'
require 'uri'
require 'date'
require 'time'
require 'rubygems'
require 'yaml'
require 'set'
begin
  require 'fastthread'
rescue LoadError
end

# for __DIR__
require Pathname(__FILE__).dirname.expand_path + 'data_mapper/support/kernel'

require __DIR__ + 'data_mapper/support/object'
require __DIR__ + 'data_mapper/support/blank'
require __DIR__ + 'data_mapper/support/enumerable'
require __DIR__ + 'data_mapper/support/symbol'
require __DIR__ + 'data_mapper/support/inflection'
require __DIR__ + 'data_mapper/support/struct'

require __DIR__ + 'data_mapper/logger'
require __DIR__ + 'data_mapper/dependency_queue'
require __DIR__ + 'data_mapper/repository'
require __DIR__ + 'data_mapper/resource'
require __DIR__ + 'data_mapper/query'
require __DIR__ + 'data_mapper/type_map'
require __DIR__ + 'data_mapper/adapters/abstract_adapter'
require __DIR__ + 'data_mapper/cli'
require __DIR__ + 'data_mapper/migrator'
require __DIR__ + 'data_mapper/auto_migrations'
require __DIR__ + 'data_mapper/migrations/destructive_migrations'
require __DIR__ + 'data_mapper/scope'
require __DIR__ + 'data_mapper/query'

require __DIR__ + 'data_mapper/types/enum'
require __DIR__ + 'data_mapper/types/flag'

module DataMapper
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

    unless Adapters::const_defined?(DataMapper::Inflection.classify(adapter_name) + 'Adapter')
      begin
        require __DIR__ + "data_mapper/adapters/#{DataMapper::Inflection.underscore(adapter_name)}_adapter"
      rescue LoadError
        require "#{DataMapper::Inflection.underscore(adapter_name)}_adapter"
      end
    end

    Repository.adapters[name] = Adapters::
      const_get(DataMapper::Inflection.classify(adapter_name) + 'Adapter').new(name, uri_or_options)
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
end
