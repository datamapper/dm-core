# This file begins the loading sequence.
#
# Quick Overview:
# * Requires set, fastthread, support libs, and base
# * Sets the applications root and environment for compatibility with rails or merb
# * Checks for the database.yml and loads it if it exists
# * Sets up the database using the config from the yaml file or from the environment
# 

# Require the basics...
require 'pathname'
require 'uri'
require 'date'
require 'time'
require 'rubygems'
require 'yaml'
require 'set'
begin
  require 'fastthread'
rescue LoadError
end

# for __DIR__
require Pathname(__FILE__).dirname.expand_path + 'data_mapper/support/kernel'

require __DIR__ + 'data_mapper/support/object'
require __DIR__ + 'data_mapper/support/blank'
require __DIR__ + 'data_mapper/support/enumerable'
require __DIR__ + 'data_mapper/support/symbol'
require __DIR__ + 'data_mapper/support/inflection'
require __DIR__ + 'data_mapper/support/struct'

require __DIR__ + 'data_mapper/dependency_queue'
require __DIR__ + 'data_mapper/resource'
require __DIR__ + 'data_mapper/adapters/abstract_adapter'
require __DIR__ + 'data_mapper/cli'
require __DIR__ + 'data_mapper/scope'
<<<<<<< HEAD:lib/data_mapper.rb
require __DIR__ + 'data_mapper/query'

require __DIR__ + 'data_mapper/types/enum'
require __DIR__ + 'data_mapper/types/flag'
=======
require __DIR__ + 'data_mapper/query'
>>>>>>> master:lib/data_mapper.rb
