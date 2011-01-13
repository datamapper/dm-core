require 'addressable/uri'
require 'bigdecimal'
require 'bigdecimal/util'
require 'date'
require 'pathname'
require 'set'
require 'time'
require 'yaml'

module DataMapper
  module Undefined; end
end

begin

  # Prefer active_support

  require 'active_support/core_ext/kernel/singleton_class'
  require 'active_support/core_ext/class/inheritable_attributes'
  require 'active_support/core_ext/object/blank'
  require 'active_support/core_ext/hash/except'

  require 'active_support/hash_with_indifferent_access'
  require 'active_support/inflector'

  Mash = ActiveSupport::HashWithIndifferentAccess

  require 'dm-core/core_ext/hash'
  require 'dm-core/core_ext/object'
  require 'dm-core/core_ext/string'

  module DataMapper
    Inflector = ActiveSupport::Inflector
  end

rescue LoadError

  # Default to extlib

  require 'extlib/inflection'
  require 'extlib/mash'
  require 'extlib/string'
  require 'extlib/class'
  require 'extlib/hash'
  require 'extlib/object'
  require 'extlib/blank'

  class Object
    unless respond_to?(:singleton_class)
      def singleton_class
        class << self; self end
      end
    end
  end

  module DataMapper
    Inflector = Extlib::Inflection
  end

end

begin
  require 'fastthread'
rescue LoadError
  # fastthread not installed
end

require 'dm-core/core_ext/pathname'
require 'dm-core/core_ext/module'
require 'dm-core/core_ext/array'

require 'dm-core/support/chainable'
require 'dm-core/support/deprecate'
require 'dm-core/support/descendant_set'
require 'dm-core/support/equalizer'
require 'dm-core/support/assertions'
require 'dm-core/support/lazy_array'
require 'dm-core/support/local_object_space'
require 'dm-core/support/hook'
require 'dm-core/support/subject'

require 'dm-core/collection'

require 'dm-core/type'
require 'dm-core/types/boolean'
require 'dm-core/types/discriminator'
require 'dm-core/types/text'
require 'dm-core/types/object'
require 'dm-core/types/serial'

require 'dm-core/property'
require 'dm-core/property/object'
require 'dm-core/property/string'
require 'dm-core/property/binary'
require 'dm-core/property/text'
require 'dm-core/property/numeric'
require 'dm-core/property/float'
require 'dm-core/property/decimal'
require 'dm-core/property/boolean'
require 'dm-core/property/integer'
require 'dm-core/property/serial'
require 'dm-core/property/date'
require 'dm-core/property/date_time'
require 'dm-core/property/time'
require 'dm-core/property/class'
require 'dm-core/property/discriminator'

require 'dm-core/property/lookup'
require 'dm-core/property_set'

require 'dm-core/model'
require 'dm-core/model/hook'
require 'dm-core/model/is'
require 'dm-core/model/scope'
require 'dm-core/model/relationship'
require 'dm-core/model/property'

require 'dm-core/adapters'
require 'dm-core/adapters/abstract_adapter'
require 'dm-core/associations/relationship'
require 'dm-core/associations/one_to_many'
require 'dm-core/associations/one_to_one'
require 'dm-core/associations/many_to_one'
require 'dm-core/associations/many_to_many'
require 'dm-core/identity_map'
require 'dm-core/query'
require 'dm-core/query/conditions/operation'
require 'dm-core/query/conditions/comparison'
require 'dm-core/query/operator'
require 'dm-core/query/direction'
require 'dm-core/query/path'
require 'dm-core/query/sort'
require 'dm-core/repository'
require 'dm-core/resource'
require 'dm-core/resource/state'
require 'dm-core/resource/state/transient'
require 'dm-core/resource/state/immutable'
require 'dm-core/resource/state/persisted'
require 'dm-core/resource/state/clean'
require 'dm-core/resource/state/deleted'
require 'dm-core/resource/state/dirty'
require 'dm-core/support/logger'
require 'dm-core/support/naming_conventions'
require 'dm-core/version'

require 'dm-core/core_ext/kernel'             # TODO: do not load automatically
require 'dm-core/core_ext/symbol'             # TODO: do not load automatically

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
  extend DataMapper::Assertions

  class RepositoryNotSetupError < StandardError; end

  class IncompleteModelError < StandardError; end

  class PluginNotFoundError < StandardError; end

  class UnknownRelationshipError < StandardError; end

  class ObjectNotFoundError < RuntimeError; end

  class PersistenceError < RuntimeError; end

  class UpdateConflictError < PersistenceError; end

  class SaveFailureError < PersistenceError
    attr_reader :resource

    def initialize(message, resource)
      super(message)
      @resource = resource
    end
  end

  class ImmutableError < RuntimeError; end

  class ImmutableDeletedError < ImmutableError; end

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
      name = name.to_sym
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

  # Perform necessary steps to finalize DataMapper for the current repository
  #
  # This method should be called after loading all models and plugins.
  #
  # It ensures foreign key properties and anonymous join models are created.
  # These are otherwise lazily declared, which can lead to unexpected errors.
  # It also performs basic validity checking of the DataMapper models.
  #
  # @return [DataMapper] The DataMapper module
  #
  # @api public
  def self.finalize
    Model.descendants.each do |model|
      finalize_model(model)
    end
    self
  end

  private
  # @api private
  def self.finalize_model(model)
    name            = model.name
    repository_name = model.repository_name
    relationships   = model.relationships(repository_name)

    if name.to_s.strip.empty?
      raise IncompleteModelError, "#{model.inspect} must have a name"
    end

    if model.properties(repository_name).empty? &&
      !relationships.any? { |relationship| relationship.kind_of?(Associations::ManyToOne::Relationship) }
      raise IncompleteModelError, "#{name} must have at least one property or many to one relationship to be valid"
    end

    # Initialize join models and target keys
    relationships.each do |relationship|

      # If this relationship points to multiple target resources, we
      # initialize inverse many to one relationships explicitly before
      # initializing other relationships. This makes sure that foreign
      # key properties always appear in the order they were declared.
      if relationship.max > 1
        relationship.child_model.relationships.each do |inverse|
          if inverse.is_a?(Associations::ManyToOne::Relationship)
            inverse.child_key
          end
        end
      end

      relationship.child_key
      relationship.through if relationship.respond_to?(:through)
      relationship.via     if relationship.respond_to?(:via)
    end

    if model.key(repository_name).empty?
      raise IncompleteModelError, "#{name} must have a key to be valid"
    end
  end
end
