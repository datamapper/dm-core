require 'rubygems'
require 'rake'

begin
  gem 'jeweler', '~> 1.4'
  require 'jeweler'

  Jeweler::Tasks.new do |gem|
    gem.name        = 'dm-core'
    gem.summary     = 'An Object/Relational Mapper for Ruby'
    gem.description = 'Faster, Better, Simpler.'
    gem.email       = 'dan.kubb@gmail.com'
    gem.homepage    = 'http://github.com/datamapper/dm-core'
    gem.authors     = [ 'Dan Kubb' ]

    gem.rubyforge_project = 'datamapper'

    gem.add_dependency 'extlib',              '~> 0.9.14'
    gem.add_dependency 'addressable',         '~> 2.1'

    gem.add_development_dependency 'bundler', '~> 0.9.11'
    gem.add_development_dependency 'rspec',   '~> 1.3'
    gem.add_development_dependency 'yard',    '~> 0.5'

  end

  Jeweler::GemcutterTasks.new

  FileList['tasks/**/*.rake'].each { |task| import task }

rescue LoadError => e
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler'
  puts '-----------------------------------------------------------------------------'
  puts e.backtrace # Let's help by actually showing *which* dependency is missing
end


desc "Support bundling from local source code (allows BUNDLE_GEMFILE=Gemfile.local bundle exec foo)"
task :create_local_gemfile do |t|

  datamapper        = File.expand_path('../..', __FILE__)
  excluded_adapters = ENV['EXCLUDED_ADAPTERS'].to_s.split(',')

  source_regex     = /datamapper = 'git:\/\/github.com\/datamapper'/
  gem_source_regex = /:git => \"#\{datamapper\}\/(.+?)(?:\.git)?\"/

  File.open(File.expand_path('../Gemfile.local', __FILE__), 'w') do |f|
    File.open(File.expand_path('../Gemfile', __FILE__), 'r').each do |line|
      line.sub!(source_regex, "datamapper = '#{datamapper}'")
      line.sub!(gem_source_regex, ':path => "#{datamapper}/\1"')
      line = "##{line}" if excluded_adapters.any? { |name| line.include?(name) }
      f.puts line
    end
  end

end