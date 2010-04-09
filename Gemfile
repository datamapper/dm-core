source 'http://rubygems.org'

datamapper = 'git://github.com/datamapper'

group :runtime do

  # We bundle both AS and extlib while extlib compatibility needs to be kept around.
  # require 'dm-core' will ensure that only one is activated at any time though.
  # This is done by trying to require AS components and fallback to requiring
  # extlib in case a LoadError was rescued when requiring AS code.
  #
  # Due to bundle exec activating all groups in the Gemfile, it's recommended to run
  #
  #   bundle install --without quality
  #
  # to have a development environment that is able to run the specs. The problem is that
  # metric_fu activates active_support=2.2.3 if we comment out the gem 'activesupport'
  # declaration - have a look below for why we would want to do that (and a bit later, for
  # why that's actually not *strictly* necessary, but recommended)
  #
  # To run the specs using AS, leave this Gemfile as it is and just run
  #
  #   bundle install --without qality
  #   ADAPTERS=sqlite3 bundle exec rake spec # or whatever adapter
  #
  # To run the specs using extlib, comment out the: gem 'activesupport' line and run
  #
  #  bundle install --without quality
  #  ADAPTERS=sqlite3 bundle exec rake spec # or whatever adapter
  #
  # If you want to run the quality tasks as provided by metric_fu and related gems,
  # you have to run
  #
  #   bundle install
  #   bundle exec rake metrics:all
  #
  # Switch back to a bundle without quality gems before trying to run the specs again
  #
  #   bundle install --without quality
  #   ADAPTERS=sqlite3 bundle exec rake spec # or whatever adapter
  #
  # It was mentioned above that all this is not *strictly* necessary, and this is true.
  # Currently dm-core does the following as the first require when checking for AS
  #
  #   require 'active_support/core_ext/kernel/singleton_class'
  #
  # Because this method is not present in activesupport <= 3.0.0.beta, dm-core's feature
  # detection will actually do the "right thing" and fall back to extlib. However, since
  # this is not the case for all dm-more gems as well, the safest thing to do is to respect
  # the more tedious workflow for now, as it will at least be guaranteed to work the same
  # for both dm-core and dm-more.
  #
  # Note that this won't be an issue anymore once we dropped support for extlib completely,
  # or bundler folks decide to support something like "bundle exec --without=foo rake spec"
  # (which probably is not going to happen anytime soon).
  #

  if ENV['EXTLIB']
    gem 'extlib',        '~> 0.9.15',      :git => "#{datamapper}/extlib.git"
  else
    gem 'activesupport', '~> 3.0.0.beta3', :git => 'git://github.com/rails/rails.git', :require => nil
  end

  gem 'addressable', '~> 2.1'
end

group :development do

  gem 'rake',                 '~> 0.8.7'
  gem 'rspec',                '~> 1.3'
  gem 'yard',                 '~> 0.5'
  gem 'rcov',                 '~> 0.9.7'
  gem 'jeweler',              '~> 1.4'

  gem 'dm-core',              '~> 0.10.3', :path => File.dirname(__FILE__) # Make ourself available to the adapters

  gem 'dm-migrations',        '~> 0.10.3', :git => "#{datamapper}/dm-migrations.git"

  gem 'data_objects',         '~> 0.10.2', :git => "#{datamapper}/do.git"
  gem 'do_sqlite3',           '~> 0.10.2', :git => "#{datamapper}/do.git"
  gem 'do_mysql',             '~> 0.10.2', :git => "#{datamapper}/do.git"
  gem 'do_postgres',          '~> 0.10.2', :git => "#{datamapper}/do.git"
  gem 'do_oracle',            '~> 0.10.2', :git => "#{datamapper}/do.git"
  gem 'do_sqlserver',         '~> 0.10.2', :git => "#{datamapper}/do.git"

  gem 'dm-do-adapter',        '~> 0.10.3', :git => "#{datamapper}/dm-do-adapter.git"
  gem 'dm-sqlite-adapter',    '~> 0.10.3', :git => "#{datamapper}/dm-sqlite-adapter.git"
  gem 'dm-postgres-adapter',  '~> 0.10.3', :git => "#{datamapper}/dm-postgres-adapter.git"
  gem 'dm-mysql-adapter',     '~> 0.10.3', :git => "#{datamapper}/dm-mysql-adapter.git"
  gem 'dm-oracle-adapter',    '~> 0.10.3', :git => "#{datamapper}/dm-oracle-adapter.git"
  gem 'dm-sqlserver-adapter', '~> 0.10.3', :git => "#{datamapper}/dm-sqlserver-adapter.git"

  gem 'dm-yaml-adapter',      '~> 0.10.3', :git => "#{datamapper}/dm-yaml-adapter.git"

end

group :quality do
  gem 'yardstick', '~> 0.1'
  gem 'metric_fu', '~> 1.3'
  gem 'reek',      '~> 1.2.7'
  gem 'roodi',     '~> 2.1'
end
