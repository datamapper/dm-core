WIN32 = (RUBY_PLATFORM =~ /win32|mingw|bccwin|cygwin/) rescue nil
SUDO = WIN32 ? '' : ('sudo' unless ENV['SUDOLESS'])

def sudo_gem(cmd)
  sh "#{SUDO} #{RUBY} -S gem #{cmd}", :verbose => false
end

if WIN32
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
