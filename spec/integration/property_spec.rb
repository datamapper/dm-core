require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'
require 'faster_csv'

describe DataMapper::Property do
  describe" tracking strategies" do
  
    before do
      class Actor
        include DataMapper::Resource
      
        property :id, Fixnum, :serial => true
        property :name, String, :lock => true
        property :notes, DataMapper::Types::Text, :track => false
        property :age, Fixnum, :track => :set
        property :rating, Fixnum # :track default should be false for immutable types
        property :location, String # :track default should be :get for mutable types
        property :lead, TrueClass, :track => :load
        property :agent, String, :track => :hash # :track only Object#hash value on :load.
          # Potentially faster, but less safe, so use judiciously, when the odds of a hash-collision are low.
      end
    
      @adapter = DataMapper::Repository.adapters[:sqlite3] || DataMapper.setup(:sqlite3, "sqlite3://#{__DIR__}/integration_test.db")
      @adapter.execute <<-EOS.compress_lines
        CREATE TABLE actors (
          id INTEGER PRIMARY KEY,
          name TEXT,
          notes TEXT,
          age INTEGER,
          rating INTEGER,
          location TEXT,
          lead BOOLEAN,
          agent TEXT
        )
      EOS
    end
  
    it "false" do
      pending("Implementation...")
      DataMapper::Resource::DIRTY.should_not be_nil
      bob = Actor.new(:name => 'bob')
      bob.original_attributes.should have_key(:name)
      bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
    end
  
    it ":load" do
      pending("Implementation...")
      DataMapper::Resource::DIRTY.should_not be_nil
      bob = Actor.new(:name => 'bob')
      bob.original_attributes.should have_key(:name)
      bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
    end
  
    it ":hash" do
      pending("Implementation...")
      DataMapper::Resource::DIRTY.should_not be_nil
      bob = Actor.new(:name => 'bob')
      bob.original_attributes.should have_key(:name)
      bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
    end
  
    it ":get" do
      pending("Implementation...")
      DataMapper::Resource::DIRTY.should_not be_nil
      bob = Actor.new(:name => 'bob')
      bob.original_attributes.should have_key(:name)
      bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
    end
  
    it ":set" do
      pending("Implementation...")
      DataMapper::Resource::DIRTY.should_not be_nil
      bob = Actor.new(:name => 'bob')
      bob.original_attributes.should have_key(:name)
      bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
    end
    
    after do
      @adapter.execute("DROP TABLE actors")
    end
  end
end