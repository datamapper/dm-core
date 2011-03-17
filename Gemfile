require 'pathname'

source 'http://rubygems.org'

SOURCE         = ENV.fetch('SOURCE', :git).to_sym
REPO_POSTFIX   = SOURCE == :path ? ''                                : '.git'
DATAMAPPER     = SOURCE == :path ? Pathname(__FILE__).dirname.parent : 'http://github.com/datamapper'
DM_VERSION     = '~> 1.1.0'
DO_VERSION     = '~> 0.10.2'
DM_DO_ADAPTERS = %w[ sqlite postgres mysql oracle sqlserver ]

gem 'addressable', '~> 2.2.4'

group :development do

  gem 'jeweler', '~> 1.5.2'
  gem 'rake',    '~> 0.8.7'
  gem 'rspec',   '~> 1.3.1'
  gem 'yard',    '~> 0.6'

end

group :quality do

  gem 'yardstick',  '~> 0.2'
  gem 'rcov',       '~> 0.9.9', :platforms => [:mri_18]

end

group :datamapper do

  # Make ourself available to the adapters
  gem 'dm-core', DM_VERSION, :path => File.dirname(__FILE__)

  adapters = ENV['ADAPTERS'] || ENV['ADAPTER']
  adapters = adapters.to_s.tr(',', ' ').split.uniq - %w[ in_memory ]

  if (do_adapters = DM_DO_ADAPTERS & adapters).any?
    do_options = {}
    do_options[:git] = "#{DATAMAPPER}/do#{REPO_POSTFIX}" if ENV['DO_GIT'] == 'true'

    gem 'data_objects', DO_VERSION, do_options.dup

    do_adapters.each do |adapter|
      adapter = 'sqlite3' if adapter == 'sqlite'
      gem "do_#{adapter}", DO_VERSION, do_options.dup
    end

    gem 'dm-do-adapter', DM_VERSION, SOURCE => "#{DATAMAPPER}/dm-do-adapter#{REPO_POSTFIX}"
  end

  adapters.each do |adapter|
    gem "dm-#{adapter}-adapter", DM_VERSION, SOURCE => "#{DATAMAPPER}/dm-#{adapter}-adapter#{REPO_POSTFIX}"
  end

  plugins = ENV['PLUGINS'] || ENV['PLUGIN']
  plugins = plugins.to_s.tr(',', ' ').split.push('dm-migrations').uniq

  plugins.each do |plugin|
    gem plugin, DM_VERSION, SOURCE => "#{DATAMAPPER}/#{plugin}#{REPO_POSTFIX}"
  end

end
