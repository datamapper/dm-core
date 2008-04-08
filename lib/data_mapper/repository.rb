require 'uri'
require __DIR__ + 'support/errors'
require __DIR__ + 'logger'
require __DIR__ + 'adapters/abstract_adapter'
require __DIR__ + 'identity_map'
require __DIR__ + 'naming_conventions'

# Delegates to DataMapper::repository.
# Will not overwrite if a method of the same name is pre-defined.
module Kernel
  def repository(name = :default)
    unless block_given?
      begin
        DataMapper::Repository.context.last || DataMapper::Repository.new(name)
      #rescue NoMethodError
       # raise RepositoryNotSetupError, "#{name.inspect} repository not set up."
      end
    else
      begin
        return yield(DataMapper::Repository.context.push(DataMapper::Repository.new(name)))
      ensure
        # current = DataMapper::Repository.context.last
        # current.flush! if current.adapter.auto_flush?
        DataMapper::Repository.context.pop
      end
    end
  end
end # module Kernel

module DataMapper

  def self.setup(name, uri, options = {})
    uri = uri.is_a?(String) ? URI.parse(uri) : uri

    raise ArgumentError, "'name' must be a Symbol"       unless name.is_a?(Symbol)
    raise ArgumentError, "'uri' must be a URI or String" unless uri.is_a?(URI)

    unless Adapters::const_defined?(DataMapper::Inflection.classify(uri.scheme) + "Adapter")
      begin
        require __DIR__ + "adapters/#{DataMapper::Inflection.underscore(uri.scheme)}_adapter"
      rescue LoadError
        require "#{DataMapper::Inflection.underscore(uri.scheme)}_adapter"
      end
    end

    adapter = Adapters::const_get(DataMapper::Inflection.classify(uri.scheme) + "Adapter").new(name, uri)

    Repository.adapters[name] = adapter
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
  def self.repository(name = :default) # :yields: current_context
    unless block_given?
      begin
        Repository.context.last || Repository.new(name)
      #rescue NoMethodError
       # raise RepositoryNotSetupError, "#{name.inspect} repository not set up."
      end
    else
      begin
        return yield(Repository.context.push(Repository.new(name)))
      ensure
        Repository.context.pop
      end
    end
  end

  class Repository

    @adapters = {}

    def self.adapters
      @adapters
    end

    def self.context
      Thread::current[:repository_contexts] ||= []
    end

    attr_reader :name, :adapter

    def initialize(name)
      @name = name
      @adapter = self.class.adapters[name]
      @identity_map = IdentityMap.new
    end

    def identity_map_get(resource, key)
      @identity_map.get(resource, key)
    end

    def identity_map_set(resource)
      @identity_map.set(resource)
    end

    def get(resource, key)
      @identity_map.get(resource, key) || @adapter.read(self, resource, key)
    end

    def first(resource, options)
      @adapter.read_set(self, Query.new(resource, options.merge(:limit => 1))).first
    end

    def all(resource, options)
      @adapter.read_set(self, Query.new(resource, options)).entries
    end

    def save(resource)
      resource.child_associations.each { |a| a.save }

      success = if resource.new_record?
        if @adapter.create(self, resource)
          @identity_map.set(resource)
          resource.instance_variable_set(:@new_record, false)
          resource.dirty_attributes.clear
          true
        else
          false
        end
      else
        if @adapter.update(self, resource)
          resource.dirty_attributes.clear
          true
        else
          false
        end
      end

      resource.parent_associations.each { |a| a.save }
      success
    end

    def destroy(resource)
      if @adapter.delete(self, resource)
        @identity_map.delete(resource.class, resource.key)
        resource.instance_variable_set(:@new_record, true)
        resource.dirty_attributes.clear
        resource.class.properties(name).each do |property|
          resource.dirty_attributes << property if resource.attribute_loaded?(property.name)
        end
        true
      else
        false
      end
    end

  end # class Repository
end # module DataMapper
