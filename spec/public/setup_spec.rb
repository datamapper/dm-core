require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require 'pp'

describe "DataMapper.setup" do

  describe "using connection string" do
    before :all do
      @result = DataMapper.setup(:setup_test, 'in_memory://user:pass@hostname:1234/path?foo=bar&baz=foo#fragment')
      @options = @result.options
    end

    it 'should set up the repository' do
      DataMapper.repository(:setup_test).should == @result
    end

    it 'should extract options from the uri' do
      {
        :adapter  => 'in_memory',
        :user     => 'user',
        :password => 'pass',
        :host     => 'hostname',
        :port     => 1234,
        :path     => '/path',
        :fragment => 'fragment'
      }.each do |key, val|
        @result.options[key].should == val
      end
    end

    it 'should alias the scheme of the uri as the adapter' do
      @options[:scheme].should == @options[:adapter]
    end

    it 'should leave the query param intact' do
      @options[:query].should == 'foo=bar&baz=foo'
    end

    it 'should extract the query param as top-level options' do
      @options[:foo].should == 'bar'
      @options[:baz].should == 'foo'
    end

  end

  describe "using options" do
    before :all do
      @result = DataMapper.setup(:setup_test, :adapter => :in_memory, :foo => 'bar')
      @options = @result.options
    end

    it 'should set up the repository' do
      DataMapper.repository(:setup_test).should == @result
    end

    it 'should set the options given' do
      {
        :adapter => :in_memory,
        :foo     => 'bar'
      }.each do |key, val|
        @options[key].should == val
      end
    end
  end

  describe "using an instance of an adapter" do
    before :all do
      @adapter = DataMapper::Adapters::InMemoryAdapter.new(:setup_test)
      @result = DataMapper.setup(@adapter)
    end

    it 'should set up the repository' do
      DataMapper.repository(:setup_test).should == @result
    end

    it 'should use the adapter given' do
      @result.should == @adapter
    end

    it 'should use the name given to the adapter' do
      @result.name.should == @adapter.name
    end

  end

end
