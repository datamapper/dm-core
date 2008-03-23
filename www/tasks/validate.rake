
namespace :validate do

  desc 'Validate hyperlinks (exclude exteranl sites)'
  task :internal => :build do
    Webby::LinkValidator.validate(:external => false)
  end

  desc 'Validate hyperlinks (include external sites)'
  task :external => :build do
    Webby::LinkValidator.validate(:external => true)
  end

end  # validate

desc 'Alias to validate:internal'
task :validate => 'validate:internal'

# EOF
