desc "Support bundling from local source code (allows BUNDLE_GEMFILE=Gemfile.local bundle foo)"
task :local_gemfile do |t|

  root       = Pathname(__FILE__).dirname.parent
  datamapper = root.parent

  root.join('Gemfile.local').open('w') do |f|
    root.join('Gemfile').open.each do |line|
      line.sub!(/DATAMAPPER = 'git:\/\/github.com\/datamapper'/, "DATAMAPPER = '#{datamapper}'")
      line.sub!(/:git => \"#\{DATAMAPPER\}\/(.+?)(?:\.git)?\"/,  ':path => "#{DATAMAPPER}/\1"')
      line.sub!(/do_options\[:git\] = \"#\{DATAMAPPER\}\/(.+?)(?:\.git)?\"/,  'do_options[:path] = "#{DATAMAPPER}/\1"')
      f.puts line
    end
  end

end
