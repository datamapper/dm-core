unless defined?(INITIAL_CLASSES)
  # Require the DataMapper, and a Mock Adapter.
  require Pathname(__FILE__).dirname + 'lib/data_mapper'
  require Pathname(__FILE__).dirname + 'spec/mock_adapter'

  adapter = ENV["ADAPTER"] || "sqlite3"
  
  repository_uri = URI.parse case ENV["ADAPTER"]
    when 'mysql' then "mysql://localhost/data_mapper_1"
    when 'postgres' then "postgres://localhost/data_mapper_1"
    else "sqlite3:///#{Dir.pwd}/data_mapper_1.db"
  end

  # Prepare the log path, and remove the existing spec.log
  # 
  # if ENV["LOG_NAME"]
  #   log_path = nil
  #   
  #   if ENV["LOG_NAME"] != "STDOUT"
  #     log_path = Pathname(__FILE__).dirname + "log/#{ENV['LOG_NAME']}.log"
  #     log_path.dirname.mkpath
  #     log_path.unlink if log_path.file?
  #   else
  #     log_path = "STDOUT"
  #   end
  #   
  #   configuration_options.merge!(:log_stream => log_path, :log_level => DataMapper::Logger::Levels[:debug])
  # end

  # secondary_configuration_options = configuration_options.dup
  # secondary_configuration_options.merge!(:database => (adapter == "sqlite3" ? "data_mapper_2.db" : "data_mapper_2"))

  DataMapper.setup(:default, repository_uri)
  
  # Determine log path.
  ENV['_'] =~ /(\w+)/
  DataMapper::Logger.new(Pathname(__FILE__).dirname + "log/#{$1}.log", 0)
  at_exit { DataMapper.logger.close }

  Pathname.glob(Pathname(__FILE__).dirname + 'spec/models/*.rb').sort.each { |path| load path }

  # DataMapper::Repository.setup(configuration_options)
  # DataMapper::Repository.setup(:secondary, secondary_configuration_options)
  # DataMapper::Repository.setup(:mock, :adapter => MockAdapter)

  # [:default, :secondary, :mock].each { |name| repository(name) { load_models.call } }

  # Reset the test database.
  # unless ENV['AUTO_MIGRATE'] == 'false'
  #   [:default, :secondary].each { |name| repository(name) { DataMapper::Persistable.auto_migrate! } }
  # end

end
