require 'rubygems'
require 'rake'

begin
  gem 'jeweler', '~> 1.5.2'
  require 'jeweler'

  Jeweler::Tasks.new do |gem|
    gem.name        = 'dm-core'
    gem.summary     = 'An Object/Relational Mapper for Ruby'
    gem.description = 'Faster, Better, Simpler.'
    gem.email       = 'dan.kubb@gmail.com'
    gem.homepage    = 'http://github.com/datamapper/%s' % gem.name
    gem.authors     = [ 'Dan Kubb' ]
    gem.has_rdoc    = 'yard'

    gem.rubyforge_project = 'datamapper'
  end

  Jeweler::GemcutterTasks.new

  FileList['tasks/**/*.rake'].each { |task| import task }

rescue LoadError => e
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler'
  puts '-----------------------------------------------------------------------------'
  puts e.backtrace # Let's help by actually showing *which* dependency is missing
end
