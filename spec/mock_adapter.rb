require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'
require __DIR__.parent + 'lib/data_mapper/adapters/data_objects_adapter'

module DataMapper
  module Adapters
    class MockAdapter < DataMapper::Adapters::DataObjectsAdapter
  
      def create(repository, instance)
        instance
      end
  
    end
  end
end