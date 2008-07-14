#!/usr/bin/env ruby
require 'pathname'
require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'
require 'spec/rake/spectask'

require 'lib/dm-core/version'

ROOT = Pathname(__FILE__).dirname.expand_path

AUTHOR = "Sam Smoot"
EMAIL  = "ssmoot@gmail.com"
GEM_NAME = "dm-core"
GEM_VERSION = DataMapper::VERSION
RUBYFORGE_PROJECT = "datamapper"
HOMEPATH = "http://datamapper.org"

require ROOT + 'tasks/hoe'
require ROOT + 'tasks/install'
require ROOT + 'tasks/dm'
require ROOT + 'tasks/doc'
require ROOT + 'tasks/ci'