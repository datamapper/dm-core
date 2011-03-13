require 'spec_helper'
require 'dm-core/support/ext/hash'
require 'dm-core/support/mash'

describe DataMapper::Ext::Hash, "only" do
  before do
    @hash = { :one => 'ONE', 'two' => 'TWO', 3 => 'THREE', 4 => nil }
  end

  it "should return a hash with only the given key(s)" do
    DataMapper::Ext::Hash.only(@hash, :not_in_there).should == {}
    DataMapper::Ext::Hash.only(@hash, 4).should == {4 => nil}
    DataMapper::Ext::Hash.only(@hash, :one).should == { :one => 'ONE' }
    DataMapper::Ext::Hash.only(@hash, :one, 3).should == { :one => 'ONE', 3 => 'THREE' }
  end
end


describe Hash, 'to_mash' do
  before do
    @hash = Hash.new(10)
  end

  it "copies default Hash value to Mash" do
    @mash = DataMapper::Ext::Hash.to_mash(@hash)
    @mash[:merb].should == 10
  end
end
