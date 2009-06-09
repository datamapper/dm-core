# when yard's ready, it'll have to come back, but for now...
Rake::RDocTask.new('doc') do |config|
  config.rdoc_dir = 'doc'
  config.title    = 'DataMapper - Ruby Object Relational Mapper'
  config.options  = %w[ --line-numbers --inline-source --all ]
  config.rdoc_files.include('README.txt', 'QUICKLINKS', 'FAQ', 'lib/**/**/*.rb')
end

begin
  # sudo gem install lsegal-yard --source http://gems.github.com
  gem 'lsegal-yard', '~>0.2.3'
  require 'yard'

  YARD::Rake::YardocTask.new('yardoc') do |config|
    config.files   << 'lib/**/*.rb' << 'CONTRIBUTING' << 'History.txt'
#    config.readme = 'README.txt'
  end
rescue LoadError
  # yard not installed
end
