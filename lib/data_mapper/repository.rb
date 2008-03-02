require 'logger'
require 'data_mapper/context'
require 'data_mapper/adapters/abstract_adapter'

# Delegates to DataMapper::repository.
# Will not overwrite if a method of the same name is pre-defined.
def repository(name = :default, &block)
  DataMapper::repository(name, &block)
end unless methods.include?(:repository)
alias repo repository

module DataMapper
  
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
      Repository.context.last || Context.new(Repository[name].adapter)
    else
      begin
        Repository.context.push(Context.new(Repository[name].adapter))
        return yield(Repository.context.last)
      ensure
        Repository.context.pop
      end
    end
  end
  
  class RepositoryError < StandardError
    attr_accessor :options
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
    
    # Returns the array of Repository sessions currently being used
    #
    # This is what gives us thread safety, boys and girls
    def self.context
      Thread::current[:repository_contexts] || Thread::current[:repository_contexts] = []
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
    #    :repository => 'selecta_development'
    #   })
    #
    #
    #   DataMapper::Repository.setup(:named_repository, {
    #    :adapter  => 'mysql'
    #    :host     => 'localhost'
    #    :username => 'root'
    #    :password => 'R00tPaswooooord'
    #    :repository => 'selecta_development'
    #   })
    
    def self.setup(*args)
      
      name, options = nil
      
      if (args.nil?) || (args[1].nil? && args[0].class != Hash)
        raise ArgumentError.new('Repository cannot be setup without at least an options hash.')
      end
      
      if args.size == 1
        name, options = :default, args[0]
      elsif args.size == 2
        name, options = args[0], args[1]
      end        
      
      current = self.new(name)
      
      current.single_threaded = false if options[:single_threaded] == false
      
      options.each_pair do |k,v|
        current.send("#{k}=", v)
      end
      
      @repositories[name] = current
    end
    
    # Creates a new repository object with the name you specify, and a default set of options.
    #
    # The default options are as follows:
    #   { :host => 'localhost', :database => nil, :port => nil, :username => 'root', :password => '', :adapter = nil }
    def initialize(name)
      @name = name
      
      @adapter = nil
      @host = "localhost"
      @database = nil
      @port = nil
      @schema_search_path = nil
      @username = "root"
      @password = ''
      @socket = nil
      
      @log_level = DataMapper::Logger::Levels[:warn]
      @log_stream = nil
    end
    
    attr_reader :name, :adapter, :log_stream
    
    attr_accessor :host, :database, :port, :schema_search_path, :username, :password, :log_level, :index_path, :socket
    
    def log_stream=(val)
      @log_stream = (val.is_a?(String) && val =~ /STDOUT/ ? STDOUT : val)
    end
    
    # Allows us to set the adapter for this repository object. It can only be set once, and expects two types of values.
    #
    # You may pass in either a class inheriting from DataMapper::Adapters::AbstractAdapter
    # or pass in a string indicating the type of adapter you would like to use.
    #
    # To create your own adapters, create a file in data_mapper/adapters/new_adapter.rb that inherits from AbstractAdapter
    #
    #   repository.adapter=("postgresql")
    def adapter=(value)
      if @adapter
        raise ArgumentError.new("The adapter is readonly after being set")
      end
      
      if value.is_a?(DataMapper::Adapters::AbstractAdapter)
        @adapter = value
      elsif value.is_a?(Class)
        @adapter = value.new(self)
      else
        begin
          require "data_mapper/adapters/#{Inflector.underscore(value)}_adapter"
        rescue LoadError
          require "#{Inflector.underscore(value)}_adapter"
        end
        adapter_class = Adapters::const_get(Inflector.classify(value) + "Adapter")
      
        @adapter = adapter_class.new(self)
      end
    end
    
    def logger
      @logger = DataMapper::Logger.new(@log_stream, @log_level)
      #create_logger
    
      class << self
        attr_reader :logger
      end
      at_exit { @logger.close }
      return @logger
    end
    
    #def create_logger
    #  x = Logger.new(@log_stream, File::WRONLY | File::APPEND | File::CREAT)
    #  x.level = @log_level
    #  at_exit { x.close }
    #  return x
    #end
  end
  
end
