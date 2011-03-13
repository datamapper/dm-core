require 'spec_helper'
require 'dm-core/support/ext/array'
require 'dm-core/support/mash'

describe DataMapper::Ext::Array do
  before :all do
    @array = [ [ :a, [ 1 ] ], [ :b, [ 2 ] ], [ :c, [ 3 ] ] ].freeze
  end

  describe '.to_hash' do
    before :all do
      @return = DataMapper::Ext::Array.to_hash(@array)
    end

    it 'should return a Hash' do
      @return.should be_kind_of(Hash)
    end

    it 'should return expected value' do
      @return.should == { :a => [ 1 ], :b => [ 2 ], :c => [ 3 ] }
    end
  end

  describe '.to_mash' do
    before :all do
      @return = DataMapper::Ext::Array.to_mash(@array)
    end

    it 'should return a Mash' do
      @return.should be_kind_of(DataMapper::Mash)
    end

    it 'should return expected value' do
      @return.should == { 'a' => [ 1 ], 'b' => [ 2 ], 'c' => [ 3 ] }
    end
  end
end
