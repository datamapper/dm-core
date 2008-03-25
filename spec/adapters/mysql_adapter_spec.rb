require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'data_mapper', 'adapters', 'mysql_adapter')

describe DataMapper::Adapters::MysqlAdapter do
  before do
    @uri = URI.parse("mysql://localhost/over_nine_thousand&socket=/tmp/da.sock")
  end

  it 'should override the path when the option is passed' do
    options = {
      :host => 'davidleal.com',
      :user => 'me',
      :password => 'mypass',
      :port => 5000,
      :database => 'you_can_call_me_al'
    }
    adapter = DataMapper::Adapters::MysqlAdapter.new(:mock, @uri, options)
    adapter.instance_variable_get("@uri").should == URI.parse("mysql://me:mypass@davidleal.com:5000/you_can_call_me_all")
  end

  it 'should accept the uri when no overrides exist' do
    adapter = DataMapper::Adapters::MysqlAdapter.new(:mock, @uri)
    adapter.instance_variable_get("@uri").should == @uri
  end
end
