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

    gem.add_dependency 'extlib',      '~> 0.9.14'
    gem.add_dependency 'addressable', '~> 2.1'

    gem.add_development_dependency 'rspec', '~> 1.2.9'
    gem.add_development_dependency 'yard',  '~> 0.4.0'
  end

  Jeweler::GemcutterTasks.new

  FileList['tasks/**/*.rake'].each { |task| import task }
rescue LoadError
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler'
end
