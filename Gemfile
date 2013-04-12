require File.expand_path('../lib/dm-core/version', __FILE__)

require 'pathname'

source 'https://rubygems.org'

gemspec

SOURCE         = ENV.fetch('SOURCE', :git).to_sym
REPO_POSTFIX   = SOURCE == :path ? ''                                : '.git'
DATAMAPPER     = SOURCE == :path ? Pathname(__FILE__).dirname.parent : 'http://github.com/datamapper'
DM_VERSION     = '~> 1.2.0'
DO_VERSION     = '~> 0.10.6'
DM_DO_ADAPTERS = %w[ sqlite postgres mysql oracle sqlserver ]
CURRENT_BRANCH = ENV.fetch('GIT_BRANCH', 'master')

group :development do

  gem 'jeweler', '~> 1.6.4'
  gem 'rake',    '~> 0.9.2'
  gem 'rspec',   '~> 1.3.2'

end

platforms :mri_18 do
  group :quality do

    gem 'rcov',      '~> 0.9.10'
    gem 'yard',      '~> 0.7.2'
    gem 'yardstick', '~> 0.4'

  end
end

group :datamapper do

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

    gem 'dm-do-adapter', DM_VERSION,
      SOURCE  => "#{DATAMAPPER}/dm-do-adapter#{REPO_POSTFIX}",
      :branch => CURRENT_BRANCH
  end

  adapters.each do |adapter|
    gem "dm-#{adapter}-adapter", ENV.fetch('ADAPTER_VERSION', DM_VERSION),
      SOURCE  => "#{DATAMAPPER}/dm-#{adapter}-adapter#{REPO_POSTFIX}",
      :branch => CURRENT_BRANCH
  end

  plugins = ENV['PLUGINS'] || ENV['PLUGIN']
  plugins = plugins.to_s.tr(',', ' ').split.push('dm-migrations').uniq

  plugins.each do |plugin|
    gem plugin, DM_VERSION,
      SOURCE  => "#{DATAMAPPER}/#{plugin}#{REPO_POSTFIX}",
      :branch => CURRENT_BRANCH
  end

end
