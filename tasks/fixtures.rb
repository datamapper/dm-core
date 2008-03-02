namespace :dm do
  namespace :fixtures do
    require 'yaml'
    
    def fixtures_path
      return ENV['FIXTURE_PATH'] if ENV['FIXTURE_PATH']
      
      fixture_path = %w(db dev schema spec).find do |parent|
        File.exists?("#{DM_APP_ROOT}/#{parent}/fixtures")
      end
      
      raise "Fixtures path not found." unless fixture_path
      
      "#{DM_APP_ROOT}/#{fixture_path}/fixtures"
    end
    
    task :dm_app_root do
      p DM_APP_ROOT
    end
    
    desc 'Dump database fixtures'
    task :dump do
      ENV['AUTO_MIGRATE'] = 'false'
      Rake::Task['environment'].invoke
      directory fixtures_path
      DataMapper::Base.subclasses.each do |klass|
        table = repository.table(klass)
        puts "Dumping #{table}"
        File.open( "#{fixtures_path}/#{table}.yaml", "w+") do |file|
          file.write YAML::dump(klass.all)
        end
      end
    end
    
    desc 'Load database fixtures'
    task :load do
      Rake::Task['environment'].invoke
      directory fixtures_path
      DataMapper::Base.subclasses.each do |klass|
        table = repository.table(klass)
        file_name = "#{fixtures_path}/#{table}.yaml"
        next unless File.exists?( file_name )
        puts "Loading #{table}"
        klass.delete_all
        File.open( file_name, "r") do |file|
          YAML::load(file).each do |attributes|
            klass.create(attributes)
          end
        end
      end
    end
  end
end
