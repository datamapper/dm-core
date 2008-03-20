namespace :dm do
  namespace :fixtures do
    require 'yaml'
    
    def fixtures_path
      @fixture_path ||= if ENV['FIXTURE_PATH']
        Pathname(ENV['FIXTURE_PATH'])
      else
        Pathname.glob("#{DM_APP_ROOT}/{db,dev,schema,spec}/fixtures").first || raise('Fixtures path not found.')
      end
    end
    
    task :dm_app_root do
      p DM_APP_ROOT
    end
    
    desc 'Dump database fixtures'
    task :dump do
      ENV['AUTO_MIGRATE'] = 'false'
      Rake::Task['environment'].invoke
      fixtures_path.mkpath
      DataMapper::Base.subclasses.each do |klass|
        table = repository.table(klass)
        puts "Dumping #{table}"
        (fixtures_path + "#{table}.yaml").open('w+') do |file|
          file.write YAML::dump(klass.all)
        end
      end
    end
    
    desc 'Load database fixtures'
    task :load do
      Rake::Task['environment'].invoke
      fixtures_path.mkpath
      DataMapper::Base.subclasses.each do |klass|
        table = repository.table(klass)
        file_name = fixtures_path + "#{table}.yaml"
        next unless file_name.file?
        puts "Loading #{table}"
        klass.delete_all
        file_name.open('r') do |file|
          YAML::load(file).each do |attributes|
            klass.create(attributes)
          end
        end
      end
    end
  end
end
