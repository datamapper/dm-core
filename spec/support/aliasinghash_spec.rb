require __DIR__.parent + 'spec_helper'
require __DIR__.parent.parent + "lib/data_mapper/support/aliasinghash.rb"

describe DataMapper::Support::AliasingHash do
  
  before(:all) do
  end
  
  it 'should have key_aliases initialized as empty hash' do
    hash = AliasingHash.new()
    
    hash.aliases.should == {}
  end
  
  it 'should have key_aliases initialized as empty hash' do
    hash = AliasingHash[]
    
    hash.aliases.should == {}
  end
  
  it 'should read keys as regular hash' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    
    hash[:a].should == "test a"
    hash[:b].should == "test b"
  end
  
  it 'should fetch keys like regular hash' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    hash.alias!(:a, :a1)
    
    hash.fetch(:a).should == "test a"
    hash.fetch(:a1).should == "test a"
    hash.fetch(:b).should == "test b"
  end
  
  it 'should return keys including aliases' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    hash.alias!(:a, :a1)
    
    (hash.keys - [:a, :a1, :b]).size.should == 0
  end
  
  it 'should acceps aliases in has_key?' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    hash.alias!(:a, :a1)
    
    hash.has_key?(:a).should == true
    hash.has_key?(:a1).should == true
    hash.has_key?(:b).should == true
    hash.has_key?(:c).should == false
  end
  
  it 'should read keys as regular hash even with aliases present' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    hash.alias!(:a, :a1)
    hash.alias!(:a, :a2)
    hash.alias!(:b, :b1)
    
    hash[:a].should == "test a"
    hash[:a1].should == "test a"
    
    hash[:b].should == "test b"
    hash[:b1].should == "test b"
  end
  
  it 'should be able to alias any time' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    hash[:a].should == "test a"
    
    hash.alias!(:a, :a1)
    hash[:a].should == "test a"
    hash[:a1].should == "test a"
    hash[:b].should == "test b"
    
    hash.alias!(:a, :a2)
    hash[:a].should == "test a"
    hash[:a1].should == "test a"
    hash[:a2].should == "test a"    
    
    hash.alias!(:b, :b1)
    hash[:a].should == "test a"
    hash[:a1].should == "test a"
    hash[:b].should == "test b"
    hash[:b1].should == "test b"
  end
  
  it 'should assign values like a regular hash' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    
    hash[:a] = "a test"
    hash[:a].should == "a test"
  end
  
  it 'should assign values through aliases' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    hash.alias!(:a, :a1)
    hash[:a1] = "a test"
    
    hash[:a].should == "a test"
  end
  
  it 'should return list of aliases for a key' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    hash.alias!(:a, :a1)
    hash.alias!(:a, :a2)
    hash.alias!(:b, :b1)
    
    (hash.key_aliases(:a) - [:a1, :a2]).size.should == 0
  end
  
  it "should return an empty array if specified key doesn't exist" do
    hash = AliasingHash[:a => "test a", :b => "test b"]

    hash.key_aliases(:c).should == []
  end
  
  it 'should raise CantAliasAliasesException if there is an attempt to alias an alias' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    hash.alias!(:a, :a1)
    lambda { hash.alias!(:a1, :a2) }.should raise_error(DataMapper::Support::AliasingHash::CantAliasAliasesException)
  end
  
  it 'should raise AliasAlreadyExistsException if there is an attempt to alias an alias' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    hash.alias!(:a, :a1)
    lambda { hash.alias!(:b, :a1) }.should raise_error(DataMapper::Support::AliasingHash::AliasAlreadyExistsException)
  end
  
  it 'should raise KeyAlreadyExistsException if there is an attempt to alias an alias' do
    hash = AliasingHash[:a => "test a", :b => "test b"]
    lambda { hash.alias!(:a, :b) }.should raise_error(DataMapper::Support::AliasingHash::KeyAlreadyExistsException)
  end
  
  it 'shold be able to handle arbitrary object aliases' do
    hash = AliasingHash[:a => 1, :b => 2]
    hash.alias!(:a, "3")
    hash["3"] = 2
    
    hash["3"].should == 2
  end
end