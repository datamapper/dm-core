# This file begins the loading sequence.
#
# Quick Overview:
# * Requires set, fastthread, support libs, and base
# * Sets the applications root and environment for compatibility with rails or merb
# * Checks for the database.yml and loads it if it exists
# * Sets up the database using the config from the yaml file or from the environment
# * 

# This line just let's us require anything in the +lib+ sub-folder
# without specifying a full path.
$:.unshift(File.dirname(__FILE__))

# Require the basics...
require 'uri'
require 'date'
require 'time'
require 'rubygems'
require 'yaml'
require 'set'
require 'fastthread'

require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'object')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'blank')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'enumerable')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'symbol')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'inflector')
require File.join(File.dirname(__FILE__), 'data_mapper', 'support', 'struct')

require File.join(File.dirname(__FILE__), 'data_mapper', 'dependency_queue')

require File.join(File.dirname(__FILE__), 'data_mapper', 'resource')

require File.join(File.dirname(__FILE__), 'data_mapper', 'adapters', 'abstract_adapter')

require File.join(File.dirname(__FILE__), 'data_mapper', 'cli')