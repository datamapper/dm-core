#!/usr/bin/env ruby
require 'pathname'
require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'
require 'spec/rake/spectask'

CLEAN.include '{coverage,doc,log}/', 'profile_results.*'

ROOT = Pathname(__FILE__).dirname.expand_path

NAME = "dm-core"

require "lib/dm-core/version"
Pathname.glob(ROOT + 'tasks/**/*.rb') { |t| require t }

##############################################################################
# Packaging & Installation
##############################################################################

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

gem_spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = NAME
  s.summary = "An Object/Relational Mapper for Ruby"
  s.description = "Faster, Better, Simpler."
  s.version = DataMapper::VERSION

  s.authors = "Sam Smoot"
  s.email = "ssmoot@gmail.com"
  s.rubyforge_project = NAME
  s.homepage = "http://datamapper.org"

  s.files = PACKAGE_FILES.map { |f| f.to_s }

  s.require_path = "lib"
  s.requirements << "none"
  s.add_dependency("data_objects", "=#{s.version}")
  s.add_dependency("extlib", "=#{s.version}")
  s.add_dependency("rspec", ">=1.1.3")
  s.add_dependency("addressable", ">=1.0.4")

  s.has_rdoc = false
  #s.rdoc_options << "--line-numbers" << "--inline-source" << "--main" << "README"
  #s.extra_rdoc_files = DOCUMENTED_FILES.map { |f| f.to_s }
end

Rake::GemPackageTask.new(gem_spec) do |p|
  p.gem_spec = gem_spec
  p.need_tar = true
  p.need_zip = true
end

desc "Publish to RubyForge"
task :rubyforge => [ :yardoc, :gem ] do
  Rake::SshDirPublisher.new("#{ENV['RUBYFORGE_USER']}@rubyforge.org", "/var/www/gforge-projects/datamapper", 'doc').upload
end

WINDOWS = (RUBY_PLATFORM =~ /win32|mingw|bccwin|cygwin/) rescue nil

desc "Install #{NAME}"
if WINDOWS
  task :install => :gem do
    system %{gem install --no-rdoc --no-ri -l pkg/#{NAME}-#{DataMapper::VERSION}.gem}
  end
  namespace :dev do
    desc 'Install for development (for windows)'
    task :winstall => :gem do
      warn "You can now call 'rake install' instead of 'rake dev:winstall'."
      system %{gem install --no-rdoc --no-ri -l pkg/#{NAME}-#{DataMapper::VERSION}.gem}
    end
  end
else
  task :install => :package do
    sh %{#{'sudo' unless ENV['SUDOLESS']} gem install --local pkg/#{NAME}-#{DataMapper::VERSION}.gem}
  end
end
