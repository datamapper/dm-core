#!/usr/bin/env ruby

require 'pathname'
require 'rubygems'
require 'rake'
require Pathname('spec/rake/spectask')
require Pathname('rake/rdoctask')
require Pathname('rake/gempackagetask')
require Pathname('rake/contrib/rubyforgepublisher')

ROOT = Pathname(__FILE__).dirname.expand_path

Pathname.glob(ROOT + 'tasks/**/*.rb') { |t| require t }

task :default     => 'dm:spec'
task :spec        => 'dm:spec'
task :environment => 'dm:environment'

desc 'Remove all package, rdocs and spec products'
task :clobber_all => %w[ clobber_package clobber_rdoc dm:clobber_spec ]

namespace :dm do
  desc "Setup Environment"
  task :environment do
    require 'environment'
  end

  def run_spec(name, files)
    Spec::Rake::SpecTask.new(name) do |t|
      t.spec_opts = ["--format", "specdoc", "--colour"]
      t.spec_files = Pathname.glob(ENV['FILES'] || files)
      unless ENV['NO_RCOV']
        t.rcov = true
        t.rcov_opts << '--exclude' << 'spec,environment.rb'
        t.rcov_opts << '--text-summary'
        t.rcov_opts << '--sort' << 'coverage' << '--sort-reverse'
        t.rcov_opts << '--only-uncovered'
      end
    end
  end

  desc "Run all specifications"
  task :spec => ['dm:spec:unit', 'dm:spec:integration']

  namespace :spec do
    desc "Run unit specifications"
    run_spec('unit', Pathname.glob(ROOT + 'spec/unit/**/*_spec.rb'))

    desc "Run integration specifications"
    run_spec('integration', Pathname.glob(ROOT + 'spec/integration/**/*_spec.rb'))
  end

  desc "Run comparison with ActiveRecord"
  task :perf do
    load Pathname.glob(ROOT + 'script/performance.rb')
  end

  desc "Profile DataMapper"
  task :profile do
    load Pathname.glob(ROOT + 'script/profile.rb')
  end
end

PACKAGE_VERSION = '0.9.0'

PACKAGE_FILES = [
  'README',
  'FAQ',
  'QUICKLINKS',
  'CHANGELOG',
  'MIT-LICENSE',
  '*.rb',
  'lib/**/*.rb',
  'spec/**/*.{rb,yaml}',
  'tasks/**/*',
  'plugins/**/*'
].collect { |pattern| Pathname.glob(pattern) }.flatten.reject { |path| path.to_s =~ /(\/db|Makefile|\.bundle|\.log|\.o)\z/ }

DOCUMENTED_FILES = PACKAGE_FILES.reject do |path|
  path.directory? || path.to_s.match(/(?:^spec|\/spec|\/swig\_)/)
end

PROJECT = "dm-core"

desc 'List all package files'
task :ls do
  puts PACKAGE_FILES
end

desc "Generate Documentation"
rd = Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title = "DataMapper -- An Object/Relational Mapper for Ruby"
  rdoc.options << '--line-numbers' << '--inline-source' << '--main' << 'README'
  rdoc.rdoc_files.include(*DOCUMENTED_FILES.map { |file| file.to_s })
end

gem_spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = PROJECT
  s.summary = "An Object/Relational Mapper for Ruby"
  s.description = "Faster, Better, Simpler."
  s.version = PACKAGE_VERSION

  s.authors = "Sam Smoot"
  s.email = "ssmoot@gmail.com"
  s.rubyforge_project = PROJECT
  s.homepage = "http://datamapper.org"

  s.files = PACKAGE_FILES.map { |f| f.to_s }

  s.require_path = "lib"
  s.requirements << "none"
  s.add_dependency("english")
  s.add_dependency("json_pure")
  s.add_dependency("rspec")
  s.add_dependency("data_objects", ">=0.9.0")
  s.add_dependency("english")

  s.has_rdoc = true
  s.rdoc_options << "--line-numbers" << "--inline-source" << "--main" << "README"
  s.extra_rdoc_files = DOCUMENTED_FILES.map { |f| f.to_s }
end

Rake::GemPackageTask.new(gem_spec) do |p|
  p.gem_spec = gem_spec
  p.need_tar = true
  p.need_zip = true
end

desc "Publish to RubyForge"
task :rubyforge => [ :rdoc, :gem ] do
  Rake::SshDirPublisher.new("#{ENV['RUBYFORGE_USER']}@rubyforge.org", "/var/www/gforge-projects/#{PROJECT}", 'doc').upload
end

desc "Install #{PROJECT}"
task :install => :package do
  sh %{sudo gem install pkg/#{PROJECT}-#{PACKAGE_VERSION}}
end

if RUBY_PLATFORM.match(/mswin32|cygwin|mingw|bccwin/)
  namespace :dev do
    desc 'Install for development (for windows)'
    task :winstall => :gem do
      system %{gem install --no-rdoc --no-ri -l pkg/#{PROJECT}-#{PACKAGE_VERSION}.gem}
    end
  end
end
