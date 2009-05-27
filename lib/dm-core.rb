# This file begins the loading sequence.
#
# Quick Overview:
# * Requires fastthread, support libs, and base.
# * Sets the application root and environment for compatibility with frameworks
#   such as Rails or Merb.
#

require 'addressable/uri'
require 'base64'
require 'bigdecimal'
require 'date'
require 'extlib'
require 'pathname'
require 'set'
require 'time'
require 'yaml'

begin
  require 'fastthread'
rescue LoadError
  # fastthread not installed
end

dir = Pathname(__FILE__).dirname.expand_path / 'dm-core'

require dir / 'support' / 'chainable'
require dir / 'support' / 'deprecate'

require dir / 'collection'
require dir / 'model'

require dir / 'adapters'
require dir / 'adapters' / 'abstract_adapter'
require dir / 'associations'
require dir / 'associations' / 'relationship'
require dir / 'associations' / 'one_to_many'
require dir / 'associations' / 'one_to_one'
require dir / 'associations' / 'many_to_one'
require dir / 'associations' / 'many_to_many'
require dir / 'conditions' / 'boolean_operator'
require dir / 'conditions' / 'comparisons'
require dir / 'identity_map'
require dir / 'migrations'                      # TODO: move to dm-more
require dir / 'model' / 'hook'
require dir / 'model' / 'is'
require dir / 'model' / 'scope'
require dir / 'property'
require dir / 'property_set'
require dir / 'query'
require dir / 'query' / 'direction'
require dir / 'query' / 'operator'
require dir / 'query' / 'path'
require dir / 'query' / 'sort'
require dir / 'repository'
require dir / 'resource'
require dir / 'support' / 'logger'
require dir / 'support' / 'naming_conventions'
require dir / 'transaction'                     # TODO: move to dm-more
require dir / 'type'
require dir / 'types' / 'boolean'
require dir / 'types' / 'discriminator'
require dir / 'types' / 'text'
require dir / 'types' / 'paranoid_datetime'     # TODO: move to dm-more
require dir / 'types' / 'paranoid_boolean'      # TODO: move to dm-more
require dir / 'types' / 'object'
require dir / 'types' / 'serial'
require dir / 'version'

require dir / 'core_ext' / 'kernel'             # TODO: do not load automatically
require dir / 'core_ext' / 'symbol'             # TODO: do not load automatically

# A logger should always be present. Lets be consistent with DO
DataMapper::Logger.new(StringIO.new, :fatal)

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
#   DataMapper.setup(:default, 'sqlite3://path/to/your/project/db/development.db')
#   DataMapper.setup(:default, 'mysql://localhost/dm_core_test')
#     # no auth-info
#   DataMapper.setup(:default, 'postgres://root:supahsekret@127.0.0.1/dm_core_test')
#     # with auth-info
#
#
# Alternatively, you can supply a hash as the second parameter, which would
# take the form:
#
#   DataMapper.setup(:default, {
#     :adapter  => 'adapter_name_here',
#     :database => 'path/to/repo',
#     :username => 'username',
#     :password => 'password',
#     :host     => 'hostname'
#   })
#
# === Logging
# To turn on error logging to STDOUT, issue:
#
#   DataMapper::Logger.new(STDOUT, :debug)
#
# You can pass a file location ("/path/to/log/file.log") in place of STDOUT.
# see DataMapper::Logger for more information.
#
module DataMapper
  extend Extlib::Assertions

  # TODO: move to dm-validations
  class ValidationError < StandardError; end

  class ObjectNotFoundError < StandardError; end

  class RepositoryNotSetupError < StandardError; end

  class IncompleteModelError < StandardError; end

  class PluginNotFoundError < StandardError; end

  # TODO: document
  # @api private
  def self.root
    @root ||= Pathname(__FILE__).dirname.parent.expand_path.freeze
  end

  ##
  # Setups up a connection to a data-store
  #
  # @param [Symbol] name
  #   a name for the context, defaults to :default
  # @param [Hash(Symbol => String), Addressable::URI, String] uri_or_options
  #   connection information
  #
  # @return [DataMapper::Adapters::AbstractAdapter]
  #   the resulting setup adapter
  #
  # @raise [ArgumentError] "+name+ must be a Symbol, but was..."
  #   indicates that an invalid argument was passed for name[Symbol]
  # @raise [ArgumentError] "+uri_or_options+ must be a Hash, URI or String, but was..."
  #   indicates that connection information could not be gleaned from
  #   the given uri_or_options[Hash, Addressable::URI, String]
  #
  # @api public
  def self.setup(*args)
    if args.first.kind_of?(DataMapper::Adapters::AbstractAdapter)
      adapter = args.first
    else
      name, uri_or_options = args

      options = normalize_options(uri_or_options)

      adapter_name = options[:adapter]
      class_name   = (Extlib::Inflection.classify(adapter_name) + 'Adapter').to_sym

      unless Adapters.const_defined?(class_name)
        lib_name = "#{adapter_name}_adapter"
        file     = root / 'lib' / 'dm-core' / 'adapters' / "#{lib_name}.rb"

        if file.file?
          require file
        else
          require lib_name
        end
      end

      adapter = Adapters.const_get(class_name).new(name, options)
    end

    Repository.adapters[adapter.name] = adapter
  end

  ##
  # Block Syntax
  #   Pushes the named repository onto the context-stack,
  #   yields a new session, and pops the context-stack.
  #
  # Non-Block Syntax
  #   Returns the current session, or if there is none,
  #   a new Session.
  #
  # @param [Symbol] args the name of a repository to act within or return, :default is default
  #
  # @yield [Proc] (optional) block to execute within the context of the named repository
  #
  # @api public
  def self.repository(name = nil)
    current_repository = if name
      assert_kind_of 'name', name, Symbol
      Repository.context.detect { |r| r.name == name } || Repository.new(name)
    else
      Repository.context.last || Repository.new(Repository.default_name)
    end

    if block_given?
      current_repository.scope { |*block_args| yield(*block_args) }
    else
      current_repository
    end
  end

  # Turns options hash or connection URI into
  # options hash used by the adapter
  #
  # @api private
  def self.normalize_options(uri_or_options)
    assert_kind_of 'uri_or_options', uri_or_options, Addressable::URI, Hash, String

    if uri_or_options.kind_of?(Hash)
      uri_or_options.to_mash
    else
      uri     = uri_or_options.kind_of?(String) ? Addressable::URI.parse(uri_or_options) : uri_or_options
      options = uri.to_hash.to_mash

      # Extract the name/value pairs from the query portion of the
      # connection uri, and set them as options directly.
      if options[:query]
        options.update(uri.query_values)
      end

      options[:adapter] = options[:scheme]

      options
    end
  end

end
