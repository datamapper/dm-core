# when yard's ready, it'll have to come back, but for now...
Rake::RDocTask.new("doc") do |t|
  t.rdoc_dir = 'doc'
  t.title    = "DataMapper - Ruby Object Relational Mapper"
  t.options  = ['--line-numbers', '--inline-source', '--all']
  t.rdoc_files.include("README.txt", "QUICKLINKS", "FAQ", "lib/**/**/*.rb")
end

begin
  gem 'yard', '>=0.2.1'
  require 'yard'

  YARD::Rake::YardocTask.new("yardoc") do |t|
    t.files   << 'lib/**/*.rb' << 'CONTRIBUTING' << 'History.txt'
    t.readme = 'README.txt'
  end
rescue Exception
  # yard not installed
end
