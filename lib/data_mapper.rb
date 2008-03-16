# This file begins the loading sequence.
#
# Quick Overview:
# * Requires set, fastthread, support libs, and base
# * Sets the applications root and environment for compatibility with rails or merb
# * Checks for the database.yml and loads it if it exists
# * Sets up the database using the config from the yaml file or from the environment
# * 

# This line just let's us require anything in the +lib+ sub-folder
# without specifying a full path.
$:.unshift(File.dirname(__FILE__))

# Require the basics...
require 'uri'
require 'date'
require 'time'
require 'rubygems'
require 'yaml'
require 'set'
require 'fastthread'
require 'validatable'

require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'object')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'blank')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'enumerable')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'symbol')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'silence')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'inflector')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'typed_set')

require File.join(File.dirname(__FILE__), 'data_mapper', 'dependency_queue')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'struct')
require File.join(File.dirname(__FILE__), 'data_mapper', 'persistable')
require File.join(File.dirname(__FILE__), 'data_mapper', 'resource')

require File.join(File.dirname(__FILE__), 'data_mapper', 'types', 'string')

begin
  # This block of code is for compatibility with Ruby On Rails' or Merb's database.yml
  # file, allowing you to simply require the data_mapper.rb in your
  # Rails application's environment.rb to configure the DataMapper.
  unless defined?(DM_APP_ROOT)
    application_root, application_environment = *if defined?(RAILS_ROOT)
      [RAILS_ROOT, RAILS_ENV]
    end
  
    DM_APP_ROOT = application_root || Dir::pwd
  
    if application_root && File.exists?(File.join(application_root, 'config', 'database.yml'))

      database_configurations = YAML::load_file(File.join(application_root, 'config', 'database.yml'))
      current_database_config = database_configurations[application_environment] || database_configurations[application_environment.to_sym]
    
      config = lambda { |key| current_database_config[key.to_s] || current_database_config[key] }
    
      default_database_config = {
        :adapter  => config[:adapter],
        :host     => config[:host],
        :database => config[:database],
        :username => config[:username],
        :password => config[:password],
        :socket => config[:socket]
      }
  
      DataMapper.setup(default_database_config)
    
    elsif application_root && FileTest.directory?(File.join(application_root, 'config'))
    
      %w(development testing production).map do |environment|
        <<-EOS.margin
          #{environment}:
            adapter: mysql
            username: root
            password:
            host: localhost
            #TODO don't use '/' in split
            database: #{File.dirname(DM_APP_ROOT).split('/').last}_#{environment}
        EOS
      end
    
      #File::open(application_root + '/config/database.yml')
    end
  end
rescue Exception
  warn "Could not connect to database specified by database.yml."
end
