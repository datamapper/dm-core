JRUBY   = RUBY_PLATFORM =~ /java/
WINDOWS = Gem.win_platform? || (JRUBY && ENV_JAVA['os.name'] =~ /windows/i)
SUDO    = WINDOWS ? '' : ('sudo' unless ENV['SUDOLESS'])

def sudo_gem(cmd)
  sh "#{SUDO} #{RUBY} -S gem #{cmd}", :verbose => false
end

if WINDOWS
  desc "Install #{GEM_NAME}"
  task :install => :gem do
    sudo_gem "install --no-rdoc --no-ri pkg/#{GEM_NAME}-#{GEM_VERSION}.gem"
  end
else
  desc "Install #{GEM_NAME}"
  task :install => :package do
    sudo_gem "install --no-rdoc --no-ri pkg/#{GEM_NAME}-#{GEM_VERSION}.gem"
  end
end
