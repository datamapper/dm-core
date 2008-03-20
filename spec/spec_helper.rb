require 'pp'
require 'pathname'

# for __DIR__
require Pathname(__FILE__).dirname.expand_path(Dir.getwd).parent + 'lib/data_mapper/support/kernel'

ENV['LOG_NAME'] = 'spec'
require __DIR__.parent + 'environment'
require __DIR__ + 'mock_adapter'