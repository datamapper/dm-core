require 'hoe'

@config_file = "~/.rubyforge/user-config.yml"
@config = nil
RUBYFORGE_USERNAME = "unknown"
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
  RUBYFORGE_USERNAME.replace @config["username"]
end

hoe = Hoe.new(GEM_NAME, GEM_VERSION) do |p|

  p.developer(AUTHOR, EMAIL)

  p.description = "Faster, Better, Simpler."
  p.summary = "An Object/Relational Mapper for Ruby"
  p.url = HOMEPATH

  p.rubyforge_name = RUBYFORGE_PROJECT if RUBYFORGE_PROJECT

  p.test_globs = ["spec/**/*_spec.rb"]
  p.clean_globs |= ["{coverage,doc,log}/", "profile_results.*", "**/.*.sw?", "*.gem", ".config", "**/.DS_Store"]

  p.extra_deps << ["data_objects", p.version]
  p.extra_deps << ["extlib", p.version]
  p.extra_deps << ["rspec", ">=1.1.3"]
  p.extra_deps << ["addressable", ">=1.0.4"]

end