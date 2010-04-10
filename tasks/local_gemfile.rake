desc "Support bundling from local source code (allows BUNDLE_GEMFILE=Gemfile.local bundle exec foo)"
task :create_local_gemfile do |t|

  datamapper        = File.expand_path('../../..', __FILE__)
  excluded_adapters = ENV['EXCLUDED_ADAPTERS'].to_s.split(',')

  source_regex     = /datamapper = 'git:\/\/github.com\/datamapper'/
  gem_source_regex = /:git => \"#\{datamapper\}\/(.+?)(?:\.git)?\"/

  File.open(File.expand_path('../../Gemfile.local', __FILE__), 'w') do |f|
    File.open(File.expand_path('../../Gemfile', __FILE__), 'r').each do |line|
      line.sub!(source_regex, "datamapper = '#{datamapper}'")
      line.sub!(gem_source_regex, ':path => "#{datamapper}/\1"')
      line = "##{line}" if excluded_adapters.any? { |name| line.include?(name) }
      f.puts line
    end
  end

end
