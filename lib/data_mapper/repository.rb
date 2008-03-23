require 'uri'
require __DIR__ + 'support/errors'
require __DIR__ + 'logger'
require __DIR__ + 'adapters/abstract_adapter'
require __DIR__ + 'identity_map'
require __DIR__ + 'naming_conventions'

# Delegates to DataMapper::repository.
# Will not overwrite if a method of the same name is pre-defined.
module Kernel
  def repository(name = :default, &block)
    DataMapper::repository(name, &block)
  end
end

module DataMapper
  
  # Setup creates a repository and sets all of your properties for that repository.
  # Setup looks for either a hash of options passed in to the repository or a symbolized name
  # for your repository, as well as it's hash of parameters
  #
  # If no options are passed, an ArgumentException will be raised.
  #   
  #   DataMapper::Repository.setup(name = :default, options_hash)
  #
  #   DataMapper::Repository.setup({
  #    :adapter  => 'mysql'
  #    :host     => 'localhost'
  #    :username => 'root'
  #    :password => 'R00tPaswooooord'
  #    :database => 'selecta_development'
  #   })
  #
  #
  #   DataMapper::Repository.setup(:named_repository, {
  #    :adapter  => 'mysql'
  #    :host     => 'localhost'
  #    :username => 'root'
  #    :password => 'R00tPaswooooord'
  #    :database => 'selecta_development'
  #   })
  def self.setup(name, uri)
    uri = uri.is_a?(String) ? URI.parse(uri) : uri
    
    raise ArgumentError.new("'name' must be a Symbol") unless name.is_a?(Symbol)
    raise ArgumentError.new("'uri' must be a URI or String") unless uri.is_a?(URI)
    
    unless Adapters::const_defined?(Inflector.classify(uri.scheme) + "Adapter")
      begin
        require __DIR__ + "adapters/#{Inflector.underscore(uri.scheme)}_adapter"
      rescue LoadError
        require "#{Inflector.underscore(uri.scheme)}_adapter"
      end
    end
    
    adapter = Adapters::const_get(Inflector.classify(uri.scheme) + "Adapter").new(name, uri)
    adapter.resource_naming_convention = NamingConventions::UnderscoredAndPluralized
    
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
       # raise RepositoryNotSetupError.new("#{name.inspect} repository not set up.")
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
      Thread::current[:repository_contexts] || Thread::current[:repository_contexts] = []
    end
    
    attr_reader :name, :adapter
        
    def initialize(name)
      @name = name
      @adapter = self.class.adapters[name]
      @identity_map = IdentityMap.new
    end

    def identity_map_get(type, key)
      @identity_map.get(type, key)
    end
    
    def identity_map_set(instance)
      @identity_map.set(instance)
    end
  end
  
end
