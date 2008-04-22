require "yaml"
require "irb"
require Pathname('irb/completion')
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'data_mapper'))

# TODO: error handling for:
#   missing adapter, host or database
module DataMapper

  class CLI

    class << self

      def usage
        "\nNote: If exactly one argument is given the CLI assumes it is a connection string.
        \n#{'='*80}\n= Examples\n#{'='*80}
        
        1. Use a connection string to connect to the database

          $ dm mysql://root@localhost/test_development
          
          Notes: The connection string has the format:
          
            adapter://user:password@host:port/database
          
          Where adapter is in: {mysql, pgsql, sqlite...}

        2. Load the database by specifying only cli options

          $ dm -a mysql -u root -h localhost -d test_development -e developemnt


        3. Load the database using a yaml config file and specifying the environment to use

          $ dm --yaml config/database.yml -e development


        4. Load everything from a config file, this example is equivalent to the above

          $ dm --config config/development.yml


        5. Load the database and some model files from a directory, specifying the environment

          $ dm --yaml config/database.yml -e development --models app/models


        6. Load an assumed structure of a typical merb application

          $ dm --merb -e development

        Note: This is similar to merb -i without the merb framework being loaded.
        ".gsub(/^    /,'')
      end

      attr_accessor :options, :config

      def parse_args(argv = ARGV)
        @config ||= {}

        # Build a parser for the command line arguments
        OptionParser.new do |opt|
          opt.define_head "DataMapper CLI"
          opt.banner = usage

          opt.on("-m", "--models MODELS", "The directory to load models from.") do |models|
            @config[:models] = Pathname(models)
          end

          opt.on("-c", "--config FILE", "Entire configuration structure, useful for testing scenarios.") do |config_file|
            @config = YAML::load_file Pathname(config_file)
          end

          opt.on("--merb", "--rails", "Loads application settings: config/database.yml, app/models.") do
            @config[:models] = Pathname('app/models')
            @config[:yaml]   = Pathname('config/database.yml')
          end

          opt.on("-y", "--yaml YAML", "The database connection configuration yaml file.") do |yaml_file|
            if (yaml = Pathname(yaml_file)).file?
              @config[:yaml] = yaml
            elsif (yaml = Pathname("#{Dir.getwd}/#{yaml_file}")).file?
              @config[:yaml] = yaml
            else
              raise "yaml file was specifed as #{yaml_file} but does not exist."
            end
          end

          opt.on("-l", "--log LOGFILE", "A string representing the logfile to use.") do |log_file|
            @config[:log_file] = Pathname(log_file)
          end

          opt.on("-e", "--environment STRING", "Run merb in the correct mode(development, production, testing)") do |environment|
            @config[:environment] = environment
          end

          opt.on("-a", "--adapter ADAPTER", "Number of merb daemons to run.") do |adapter|
            @config[:adapter] = adapter
          end

          opt.on("-u", "--username USERNAME", "The user to connect to the database as.") do |username|
            @config[:username] = username
          end

          opt.on("-p", "--password PASSWORD", "The password to connect to the database with") do |password|
            @config[:password] = password
          end

          opt.on("-h", "--host HOSTNAME", "Host to connect to.") do |host|
            @config[:host] = host
          end

          opt.on("-s", "--socket SOCKET", "The socket to connect to.") do |socket|
            @config[:socket] = socket
          end

          opt.on("-o", "--port PORT", "The port to connect to.") do |port|
            @config[:port] = port
          end

          opt.on("-d", "--database DATABASENAME", "Name of the database to connect to.") do |database_name|
            @config[:database] = database_name
          end

          opt.on("-?", "-H", "--help", "Show this help message") do
            puts opt 
            exit
          end

        end.parse!(argv)

      end

      def configure(args)
        if args[0] && args[0].match(/^(.+):\/\/(?:(.*)(?::(.+))?@)?(.+)\/(.+)$/)
          @options = {
            :adapter  => $1,
            :username => $2,
            :password => $3,
            :host     => $4,
            :database => $5
          }
          @config = @options.merge(:connection_string => ARGV.shift)
        else

          parse_args(args)

          @config[:environment] ||= "development"
          if @config[:config]
            @config.merge!(YAML::load_file(@config[:config]))
            @options = @config[:options]
          elsif @config[:yaml]
            @config.merge!(YAML::load_file(@config[:yaml]))
            @options = @config[@config[:environment]] || @config[@config[:environment].to_sym]
            raise "Options for environment '#{@config[:environment]}' are missing." if @options.nil?
          else
            @options = {
              :adapter  => @config[:adapter],
              :username => @config[:username],
              :password => @config[:password],
              :host     => @config[:host],
              :database => @config[:database]
            }
          end

        end
      end

      def load_models
        Pathname.glob("#{config[:models]}/**/*.rb") { |file| load file }
      end

      def start(argv = ARGV)

        begin
          configure(argv)
          DataMapper::Repository.setup options

          load_models if config[:models]

          puts "DataMapper has been loaded using the '#{options[:adapter] || options["adapter"]}' database '#{options[:database] || options["database"]}' on '#{options[:host] || options["host"]}' as '#{options[:username] || options["username"]}'"
          ENV["IRBRC"] = DataMapper.root / 'bin' / '.irbrc'
          IRB.start

        rescue => error
          puts error.message
          exit
        end

      end
    end
  end # module CLI
end # module DataMapper
