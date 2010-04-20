desc "Support bundling from local source code (allows BUNDLE_GEMFILE=Gemfile.local bundle foo)"
task :local_gemfile do |t|

  root              = Pathname(__FILE__).dirname.parent
  datamapper        = root.parent

  source_regex     = /DATAMAPPER = 'git:\/\/github.com\/datamapper'/
  gem_source_regex = /:git => \"#\{DATAMAPPER\}\/(.+?)(?:\.git)?\"/

  root.join('Gemfile.local').open('w') do |f|
    root.join('Gemfile').open.each do |line|
      line.sub!(source_regex,     "DATAMAPPER = '#{datamapper}'")
      line.sub!(gem_source_regex, ':path => "#{DATAMAPPER}/\1"')
      f.puts line
    end
  end

end
