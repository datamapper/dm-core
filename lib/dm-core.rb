# This file begins the loading sequence.
#
# Quick Overview:
# * Requires set, fastthread, support libs, and base.
# * Sets the application root and environment for compatibility with frameworks
#   such as Rails or Merb.
# * Checks for the database.yml and loads it if it exists.
# * Sets up the database using the config from the Yaml file or from the
#   environment.
#

# Require the basics...
require 'date'
require 'pathname'
require 'rubygems'
require 'set'
require 'time'
require 'yaml'
require 'addressable/uri'

begin
  require 'fastthread'
rescue LoadError
end

# for Pathname /
gem 'extlib', '>= 0.9'
require 'extlib'

dir = Pathname(__FILE__).dirname.expand_path / 'dm-core'

require dir / 'type'
require dir / 'type_map'
require dir / 'types'
require dir / 'associations'
require dir / 'auto_migrations'
require dir / 'hook'
require dir / 'identity_map'
require dir / 'logger'
require dir / 'migrator'
require dir / 'naming_conventions'
require dir / 'property_set'
require dir / 'query'
require dir / 'transaction'
require dir / 'repository'
require dir / 'resource'
require dir / 'scope'
require dir / 'support'
require dir / 'property'
require dir / 'adapters'
require dir / 'collection'

# == Setup and Configuration
# DataMapper uses URIs or a connection hash to connect to your data-store.
# URI connections takes the form of:
#   DataMapper.setup(:default, 'protocol://username:password@localhost:port/path/to/repo')
#
# Breaking this down, the first argument is the name you wish to give this
# connection.  If you do not specify one, it will be assigned :default. If you
# would like to connect to more than one data-store, simply issue this command
# again, but with a different name specified.
#
# In order to issue ORM commands without specifying the repository context, you
# must define the :default database. Otherwise, you'll need to wrap your ORM
# calls in <tt>repository(:name) { }</tt>.
#
# Second, the URI breaks down into the access protocol, the username, the
# server, the password, and whatever path information is needed to properly
# address the data-store on the server.
#
# Here's some examples
#   DataMapper.setup(:default, "sqlite3://path/to/your/project/db/development.db")
#   DataMapper.setup(:default, "mysql://localhost/dm_core_test")
#     # no auth-info
#   DataMapper.setup(:default, "postgres://root:supahsekret@127.0.0.1/dm_core_test")
#     # with auth-info
#
#
# Alternatively, you can supply a hash as the second parameter, which would
# take the form:
#
#   DataMapper.setup(:default, {
#     :adapter  => 'adapter_name_here',
#     :database => "path/to/repo",
#     :username => 'username',
#     :password => 'password',
#     :host     => 'hostname'
#   })
#
# === Logging
# To turn on error logging to STDOUT, issue:
#
#   DataMapper::Logger.new(STDOUT, 0)
#
# You can pass a file location ("/path/to/log/file.log") in place of STDOUT.
# see DataMapper::Logger for more information.
#
module DataMapper
  def self.root
    @root ||= Pathname(__FILE__).dirname.parent.expand_path
  end

  ##
  # Setups up a connection to a data-store
  #
  # @param name<Symbol> a name for the context, defaults to :default
  # @param uri_or_options<Hash{Symbol => String}, Addressable::URI, String>
  #   connection information
  #
  # @return <Repository> the resulting setup repository
  #
  # @raise <ArgumentError> "+name+ must be a Symbol, but was..." indicates that
  #   an invalid argument was passed for name<Symbol>
  # @raise <ArgumentError> "+uri_or_options+ must be a Hash, URI or String, but was..."
  #   indicates that connection information could not be gleaned from the given
  #   uri_or_options<Hash, Addressable::URI, String>
  # -
  # @api public
  def self.setup(name, uri_or_options)
    raise ArgumentError, "+name+ must be a Symbol, but was #{name.class}", caller unless Symbol === name

    case uri_or_options
      when Hash
        adapter_name = uri_or_options[:adapter]
      when String, Addressable::URI
        uri_or_options = Addressable::URI.parse(uri_or_options) if String === uri_or_options
        adapter_name = uri_or_options.scheme
      else
        raise ArgumentError, "+uri_or_options+ must be a Hash, Addressable::URI or String, but was #{uri_or_options.class}", caller
    end

    class_name = Extlib::Inflection.classify(adapter_name) + 'Adapter'

    unless Adapters::const_defined?(class_name)
      lib_name = "#{Extlib::Inflection.underscore(adapter_name)}_adapter"
      begin
        require root / 'lib' / 'dm-core' / 'adapters' / lib_name
      rescue LoadError
        require lib_name
      end
    end

    Repository.adapters[name] = Adapters::const_get(class_name).new(name, uri_or_options)
  end

  ##
  #
  # @details [Block Syntax]
  #   Pushes the named repository onto the context-stack,
  #   yields a new session, and pops the context-stack.
  #
  #     results = DataMapper.repository(:second_database) do |current_context|
  #       ...
  #     end
  #
  # @details [Non-Block Syntax]
  #   Returns the current session, or if there is none,
  #   a new Session.
  #
  #     current_repository = DataMapper.repository
  def self.repository(*args) # :yields: current_context
    raise ArgumentError, "Can only pass in one optional argument, but passed in #{args.size} arguments", caller unless args.size <= 1
    raise ArgumentError, "First optional argument must be a Symbol, but was #{args.first.inspect}", caller      unless args.empty? || Symbol === args.first

    name = args.first

    current_repository = if name
      Repository.context.detect { |r| r.name == name } || Repository.new(name)
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

  # A logger should always be present. Lets be consistent with DO
  Logger.new(nil, :off)

  ##
  # destructively migrates the repository upwards to match model definitions
  #
  # @param <Symbol> name repository to act on, :default is the default
  def self.migrate!(name = Repository.default_name)
    repository(name).migrate!
  end

  ##
  # drops and recreates the repository upwards to match model definitions
  #
  # @param <Symbol> name repository to act on, :default is the default
  def self.auto_migrate!(name = Repository.default_name)
    repository(name).auto_migrate!
  end

  def self.prepare(*args, &blk)
    yield repository(*args)
  end
end
