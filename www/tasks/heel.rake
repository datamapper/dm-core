
if HAVE_HEEL

namespace :heel do

  desc 'start the heel server to view website'
  task :run do
    sh "heel --root #{SITE.output_dir} --daemonize"
  end

  desc 'stop the heel server'
  task :kill do
    sh "heel --kill"
  end

  task :autobuild => :run do
    at_exit {sh "heel --kill"}
  end

end

task :autobuild => 'heel:autobuild'

end  # HAVE_HEEL

# EOF
