require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'data_mapper', 'adapters', 'sqlite3_adapter')

describe DataMapper::Adapters::Sqlite3Adapter do
  before do
    @uri = URI.parse("sqlite3:///test.db")
  end

  it 'should override the path when the option is passed' do
    adapter = DataMapper::Adapters::Sqlite3Adapter.new(:mock, @uri, { :path => '/test2.db' })
    adapter.instance_variable_get("@uri").should == URI.parse("sqlite3:///test2.db")
  end

  it 'should accept the uri when no overrides exist' do
    adapter = DataMapper::Adapters::Sqlite3Adapter.new(:mock, @uri)
    adapter.instance_variable_get("@uri").should == @uri
  end
end
