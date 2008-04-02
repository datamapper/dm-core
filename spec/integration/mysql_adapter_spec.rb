require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require __DIR__.parent.parent + 'lib/data_mapper'

begin
  require 'do_mysql'

  DataMapper.setup(:mysql, "mysql://localhost/dm_integration_test")
  
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
        :database => 'you_can_call_me_all'
      }
    
      adapter = DataMapper::Adapters::MysqlAdapter.new(:mock, @uri, options)
      adapter.instance_variable_get("@uri").should == URI.parse("mysql://me:mypass@davidleal.com:5000/you_can_call_me_all")
    end

    it 'should accept the uri when no overrides exist' do
      adapter = DataMapper::Adapters::MysqlAdapter.new(:mock, @uri)
      adapter.instance_variable_get("@uri").should == @uri
    end
  end
rescue LoadError
  warn "MySQL specs not run! Could not load do_mysql."
end