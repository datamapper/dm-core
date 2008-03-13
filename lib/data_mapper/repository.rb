require 'uri'
require File.join(File.dirname(__FILE__), 'support', 'errors')
require File.join(File.dirname(__FILE__), 'logger')
require File.join(File.dirname(__FILE__), 'context')
require File.join(File.dirname(__FILE__), 'adapters', 'abstract_adapter')

# Delegates to DataMapper::repository.
# Will not overwrite if a method of the same name is pre-defined.
module Kernerl
  def self.repository(name = :default, &block)
    DataMapper::repository(name, &block)
  end
end

module DataMapper
  
  def self.scope(name)
    Repository.context.last || Context.new(Repository[name])
  end
  
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
    Repository[name] = Repository.new(name, uri.is_a?(String) ? URI.parse(uri) : uri)
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
        Repository.context.last || Context.new(Repository[name])
      #rescue NoMethodError
       # raise RepositoryNotSetupError.new("#{name.inspect} repository not set up.")
      end
    else
      begin
        return yield(Repository.context.push(Context.new(Repository[name])))
      ensure
        Repository.context.pop
      end
    end
  end
  
  # The Repository class allows us to setup a default repository for use throughout our applications
  # or allows us to setup a collection of repositories to use.
  #
  # === Example
  # ==== To setup a default database
  #   DataMapper::Repository.setup({
  #    :adapter  => 'mysql'
  #    :host     => 'localhost'
  #    :username => 'root'
  #    :password => 'R00tPaswooooord'
  #    :database => 'selecta_development'
  #   })
  #
  # ==== To setup a named database
  #   DataMapper::Repository.setup(:second_repository, {
  #    :adapter  => 'postgresql'
  #    :host     => 'localhost'
  #    :username => 'second_user'
  #    :password => 'second_password'
  #    :database => 'second_database'
  #   })
  #
  #
  # ==== Working with multiple repositories (see #DataMapper::repository)
  #   DataMapper.repository(:second_repository) do
  #     ...
  #   end
  #
  #   DataMapper.repository(:default) do
  #     ...
  #   end
  #
  # or even...
  #
  #   #The below variables still hold on to their repository sessions.
  #   #So no confusion happens when passing variables around scopes.
  #
  #   DataMapper.repository(:second_repository) do
  #
  #     animal = Animal.first
  #
  #     DataMapper.repository(:default) do
  #       Animal.new(animal).save
  #     end # :default repository
  #
  #   end # :second_repository
  class Repository
    
    @repositories = {}
    
    # Allows you to access any of the named repositories you have already setup.
    #
    #   default_db = DataMapper::Repository[:default]
    #   second_db = DataMapper::Repository[:second_repository]
    def self.[](name)
      @repositories[name]
    end
    
    def self.[]=(name, repository)
      @repositories[name] = repository
    end
    
    # Returns the array of Repository sessions currently being used
    #
    # This is what gives us thread safety, boys and girls
    def self.context
      Thread::current[:repository_contexts] || Thread::current[:repository_contexts] = []
    end
    
    attr_reader :name, :uri, :adapter
        
    # Creates a new repository object with the name you specify.
    def initialize(name, uri)
      raise ArgumentError.new("'name' must be a Symbol") unless name.is_a?(Symbol)
      raise ArgumentError.new("'uri' must be a URI") unless uri.is_a?(URI)
      
      @name = name
      @uri = uri
      
      unless Adapters::const_defined?(Inflector.classify(uri.scheme) + "Adapter")
        begin
          require File.join(File.dirname(__FILE__), 'adapters', "#{Inflector.underscore(uri.scheme)}_adapter")
        rescue LoadError
          require "#{Inflector.underscore(uri.scheme)}_adapter"
        end
      end
      
      @adapter = Adapters::const_get(Inflector.classify(uri.scheme) + "Adapter").new(uri)
    end

  end
  
end
