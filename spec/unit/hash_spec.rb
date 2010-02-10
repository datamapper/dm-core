require 'dm-core/core_ext/hash'

begin
  require 'active_support/hash_with_indifferent_access'
  unless defined?(Mash)
    Mash = ActiveSupport::HashWithIndifferentAccess
  end
rescue LoadError
  require 'extlib/mash'
end

describe Hash, "only" do
  before do
    @hash = { :one => 'ONE', 'two' => 'TWO', 3 => 'THREE', 4 => nil }
  end

  it "should return a hash with only the given key(s)" do
    @hash.only(:not_in_there).should == {}
    @hash.only(4).should == {4 => nil}
    @hash.only(:one).should == { :one => 'ONE' }
    @hash.only(:one, 3).should == { :one => 'ONE', 3 => 'THREE' }
  end
end


describe Hash, 'to_mash' do
  before :each do
    @hash = Hash.new(10)
  end

  it "copies default Hash value to Mash" do
    @mash = @hash.to_mash
    @mash[:merb].should == 10
  end
end
