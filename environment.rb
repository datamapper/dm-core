unless defined?(INITIAL_CLASSES)
  # Require the DataMapper, and a Mock Adapter.
  require 'pathname'
  require Pathname(__FILE__).dirname.expand_path + 'lib/data_mapper'
  require __DIR__ + 'spec/mock_adapter'
  require 'fileutils'

  adapter = ENV["ADAPTER"] || "sqlite3"
  
  repository_uri = URI.parse case ENV["ADAPTER"]
    when 'mysql' then "mysql://localhost/data_mapper_1"
    when 'postgres' then "postgres://localhost/data_mapper_1"
    else "sqlite3://#{Dir.getwd}/data_mapper_1.db"
  end

  DataMapper.setup(:default, "mock://localhost")
  
  # Determine log path.
  ENV['_'] =~ /(\w+)/
  log_path = __DIR__ + "log/#{$1 == 'opt' ? 'spec' : $1}.log"
  
  FileUtils::mkdir_p(File.dirname(log_path))
  # FileUtils::rm(log_path) if File.exists?(log_path)
  
  DataMapper::Logger.new(log_path, 0)
  at_exit { DataMapper.logger.close }

  Pathname.glob(__DIR__ + 'spec/models/*.rb').sort.each { |path| load path }

end
