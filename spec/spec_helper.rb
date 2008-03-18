require 'pp'

# for __DIR__
require File.join(File.dirname(__FILE__), '..', 'lib', 'data_mapper', 'support', 'kernel')

ENV['LOG_NAME'] = 'spec'
require File.join(File.dirname(__FILE__), '..', 'environment')
