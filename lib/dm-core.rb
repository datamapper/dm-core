require 'addressable/uri'
require 'bigdecimal'
require 'bigdecimal/util'
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
require dir / 'support' / 'equalizer'

require dir / 'model'
require dir / 'model' / 'descendant_set'
require dir / 'model' / 'hook'
require dir / 'model' / 'is'
require dir / 'model' / 'scope'
require dir / 'model' / 'relationship'
require dir / 'model' / 'property'

require dir / 'collection'

require dir / 'type'
require dir / 'types' / 'boolean'
require dir / 'types' / 'discriminator'
require dir / 'types' / 'text'
require dir / 'types' / 'paranoid_datetime'     # TODO: move to dm-more
require dir / 'types' / 'paranoid_boolean'      # TODO: move to dm-more
require dir / 'types' / 'object'
require dir / 'types' / 'serial'

require dir / 'adapters'
require dir / 'adapters' / 'abstract_adapter'
require dir / 'associations' / 'relationship'
require dir / 'associations' / 'one_to_many'
require dir / 'associations' / 'one_to_one'
require dir / 'associations' / 'many_to_one'
require dir / 'associations' / 'many_to_many'
require dir / 'identity_map'
require dir / 'migrations'                      # TODO: move to dm-more
require dir / 'property'
require dir / 'property_set'
require dir / 'query'
require dir / 'query' / 'conditions' / 'operation'
require dir / 'query' / 'conditions' / 'comparison'
require dir / 'query' / 'operator'
require dir / 'query' / 'direction'
require dir / 'query' / 'path'
require dir / 'query' / 'sort'
require dir / 'repository'
require dir / 'resource'
require dir / 'support' / 'logger'
require dir / 'support' / 'naming_conventions'
require dir / 'transaction'                     # TODO: move to dm-more
require dir / 'version'

require dir / 'core_ext' / 'enumerable'
require dir / 'core_ext' / 'kernel'             # TODO: do not load automatically
require dir / 'core_ext' / 'symbol'             # TODO: do not load automatically

# A logger should always be present. Lets be consistent with DO
DataMapper::Logger.new(StringIO.new, :fatal)

unless defined?(Infinity)
  Infinity = 1.0/0
end

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
#   DataMapper::Logger.new($stdout, :debug)
#
# You can pass a file location ("/path/to/log/file.log") in place of $stdout.
# see DataMapper::Logger for more information.
#
module DataMapper
  extend Extlib::Assertions

  class RepositoryNotSetupError < StandardError; end

  class IncompleteModelError < StandardError; end

  class PluginNotFoundError < StandardError; end

  class UnknownRelationshipError < StandardError; end

  class ObjectNotFoundError < RuntimeError; end

  class PersistenceError < RuntimeError; end

  class UpdateConflictError < PersistenceError; end

  # Raised on attempt to operate on collection of child objects
  # when parent object is not yet saved.
  # For instance, if your article object is not saved,
  # but you try to fetch or scope down comments (1:n case), or
  # publications (n:m case), operation cannot be completed
  # because parent object's keys are not yet persisted,
  # and thus there is no FK value to use in the query.
  class UnsavedParentError < PersistenceError; end

  # @api private
  def self.root
    @root ||= Pathname(__FILE__).dirname.parent.expand_path.freeze
  end

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
    adapter = args.first

    unless adapter.kind_of?(Adapters::AbstractAdapter)
      adapter = Adapters.new(*args)
    end

    Repository.adapters[adapter.name] = adapter
  end

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
    context = Repository.context

    current_repository = if name
      assert_kind_of 'name', name, Symbol
      context.detect { |repository| repository.name == name }
    else
      name = Repository.default_name
      context.last
    end

    current_repository ||= Repository.new(name)

    if block_given?
      current_repository.scope { |*block_args| yield(*block_args) }
    else
      current_repository
    end
  end
end
