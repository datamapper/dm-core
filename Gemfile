# If you're working on more than one datamapper gem at a time, then it's
# recommended to create a local Gemfile and use this instead of the git
# sources. This will make sure that you are  developing against your
# other local datamapper sources that you currently work on. Gemfile.local
# will behave identically to the standard Gemfile apart from the fact that
# it fetches the datamapper gems from local paths. This means that you can use
# the same environment variables, like ADAPTER(S) or PLUGIN(S) when running
# bundle commands. Gemfile.local is added to .gitignore, so you don't need to
# worry about accidentally checking local development paths into git.
# In order to create a local Gemfile, all you need to do is run:
#
#   bundle exec rake local_gemfile
#
# This will give you a Gemfile.local file that points to your local clones of
# the various datamapper gems. It's assumed that all datamapper repo clones
# reside in the same directory. You can use the Gemfile.local like so for
# running any bundle command:
#
#   BUNDLE_GEMFILE=Gemfile.local bundle foo
#
# You can also specify which adapter(s) should be part of the bundle by setting
# an environment variable. This of course also works when using the Gemfile.local
#
#   bundle foo                        # dm-sqlite-adapter
#   ADAPTER=mysql bundle foo          # dm-mysql-adapter
#   ADAPTERS=sqlite,mysql bundle foo  # dm-sqlite-adapter and dm-mysql-adapter
#
# Of course you can also use the ADAPTER(S) variable when using the Gemfile.local
# and running specs against selected adapters.
#
# For easily working with adapters supported on your machine, it's recommended
# that you first install all adapters that you are planning to use or work on
# by doing something like
#
#   ADAPTERS=sqlite,mysql,postgres bundle install
#
# This will clone the various repositories and make them available to bundler.
# Once you have them installed you can easily switch between adapters for the
# various development tasks. Running something like
#
#   ADAPTER=mysql bundle exec rake spec
#
# will make sure that the dm-mysql-adapter is part of the bundle, and will be used
# when running the specs.
#
# You can also specify which plugin(s) should be part of the bundle by setting
# an environment variable. This also works when using the Gemfile.local
#
#   bundle foo                                 # dm-migrations
#   PLUGINS=dm-validations bundle foo          # dm-migrations and dm-validations
#   PLUGINS=dm-validations,dm-types bundle foo # dm-migrations, dm-validations and dm-types
#
# Of course you can combine the PLUGIN(S) and ADAPTER(S) env vars to run specs
# for certain adapter/plugin combinations.
#
# Finally, to speed up running specs and other tasks, it's recommended to run
#
#   bundle lock
#
# after running 'bundle install' for the first time. This will make 'bundle exec' run
# a lot faster compared to the unlocked version. With an unlocked bundle you would
# typically just run 'bundle install' from time to time to fetch the latest sources from
# upstream. When you locked your bundle, you need to run
#
#   bundle install --relock
#
# to make sure to fetch the latest updates and then lock the bundle again. Gemfile.lock
# is added to the .gitignore file, so you don't need to worry about accidentally checking
# it into version control.

source 'http://rubygems.org'

DATAMAPPER = 'git://github.com/datamapper'
DM_VERSION = '~> 1.0.2'

group :runtime do # Runtime dependencies (as in the gemspec)

  if ENV['EXTLIB']
    gem 'extlib',        '~> 0.9.15', :git => "#{DATAMAPPER}/extlib.git"
  else
    gem 'activesupport', '~> 3.0.0',  :git => 'git://github.com/rails/rails.git', :branch => '3-0-stable', :require => nil
  end

  gem 'addressable',     '~> 2.2'

end

group(:development) do # Development dependencies (as in the gemspec)

  gem 'rake',           '~> 0.8.7'
  gem 'rspec',          '~> 1.3', :git => 'git://github.com/snusnu/rspec', :branch => 'heckle_fix_plus_gemfile'
  gem 'jeweler',        '~> 1.4'

end

group :quality do # These gems contain rake tasks that check the quality of the source code

  gem 'metric_fu',      '~> 1.3'
  gem 'rcov',           '~> 0.9.8'
  gem 'reek',           '~> 1.2.8'
  gem 'roodi',          '~> 2.1'
  gem 'yard',           '~> 0.5'
  gem 'yardstick',      '~> 0.1'

end

group :datamapper do # We need this because we want to pin these dependencies to their git master sources

  gem 'dm-core', DM_VERSION, :path => File.dirname(__FILE__) # Make ourself available to the adapters

  adapters = ENV['ADAPTER'] || ENV['ADAPTERS']
  adapters = adapters.to_s.tr(',', ' ').split.uniq - %w[ in_memory ]

  DO_VERSION     = '~> 0.10.2'
  DM_DO_ADAPTERS = %w[ sqlite postgres mysql oracle sqlserver ]

  if (do_adapters = DM_DO_ADAPTERS & adapters).any?
    options = {}
    options[:git] = "#{DATAMAPPER}/do.git" if ENV['DO_GIT'] == 'true'

    gem 'data_objects',  DO_VERSION, options.dup

    do_adapters.each do |adapter|
      adapter = 'sqlite3' if adapter == 'sqlite'
      gem "do_#{adapter}", DO_VERSION, options.dup
    end

    gem 'dm-do-adapter', DM_VERSION, :git => "#{DATAMAPPER}/dm-do-adapter.git"
  end

  adapters.each do |adapter|
    gem "dm-#{adapter}-adapter", DM_VERSION, :git => "#{DATAMAPPER}/dm-#{adapter}-adapter.git"
  end

  plugins = ENV['PLUGINS'] || ENV['PLUGIN']
  plugins = plugins.to_s.tr(',', ' ').split.push('dm-migrations').uniq

  plugins.each do |plugin|
    gem plugin, DM_VERSION, :git => "#{DATAMAPPER}/#{plugin}.git"
  end

end
