require 'hoe'

@config_file = '~/.rubyforge/user-config.yml'
@config = nil
RUBYFORGE_USERNAME = 'unknown'
def rubyforge_username
  unless @config
    begin
      @config = YAML.load(File.read(File.expand_path(@config_file)))
    rescue
      puts <<-EOS
ERROR: No rubyforge config file found: #{@config_file}
Run 'rubyforge setup' to prepare your env for access to Rubyforge
 - See http://newgem.rubyforge.org/rubyforge.html for more details
      EOS
      exit
    end
  end
  RUBYFORGE_USERNAME.replace @config['username']
end

# Remove hoe dependency
class Hoe
  def extra_dev_deps
    @extra_dev_deps.reject! { |dep| dep[0] == 'hoe' }
    @extra_dev_deps
  end
end

# Don't use Hoe's test task
Hoe.plugins.delete(:test)

hoe = Hoe.spec(GEM_NAME) do
  developer(AUTHOR, EMAIL)

  self.version     = GEM_VERSION
  self.description = PROJECT_DESCRIPTION
  self.summary     = PROJECT_SUMMARY
  self.url         = PROJECT_URL

  self.rubyforge_name = PROJECT_NAME

  self.clean_globs |= %w[ {coverage,doc,log,tmp} **/*.{log,db} profile_results.* **/.DS_Store spec/db ]
  self.extra_deps  |= GEM_DEPENDENCIES
end
