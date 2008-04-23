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

# for Pathname /
require File.join(File.dirname(__FILE__), 'data_mapper', 'core_ext', 'pathname')

dir = Pathname(__FILE__).dirname.expand_path / 'data_mapper'

require dir / 'associations'
require dir / 'auto_migrations'
require dir / 'dependency_queue'
require dir / 'hook'
require dir / 'identity_map'
require dir / 'is'
require dir / 'loaded_set'
require dir / 'logger'
require dir / 'naming_conventions'
require dir / 'property_set'
require dir / 'query'
require dir / 'repository'
require dir / 'resource'
require dir / 'scope'
require dir / 'support'
require dir / 'type'
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

    unless Adapters::const_defined?(DataMapper::Inflection.classify(adapter_name) + 'Adapter')
      begin
        require root / 'data_mapper' / 'adapters' / "#{DataMapper::Inflection.underscore(adapter_name)}_adapter"
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
end
