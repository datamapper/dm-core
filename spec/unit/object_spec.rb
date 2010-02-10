require 'dm-core/core_ext/object'

module HactiveSupport
  class MemoizeConsideredUseless
  end
end

module Foo
  class Bar
  end
end

class Oi
  attr_accessor :foo
end

describe Object do

  describe "#full_const_get" do
    it 'returns constant by FQ name in receiver namespace' do
      Object.full_const_get("Oi").should == Oi
      Object.full_const_get("Foo::Bar").should == Foo::Bar
    end
  end

  describe "#full_const_set" do
    it 'sets constant value by FQ name in receiver namespace' do
      Object.full_const_set("HactiveSupport::MCU", HactiveSupport::MemoizeConsideredUseless)

      Object.full_const_get("HactiveSupport::MCU").should == HactiveSupport::MemoizeConsideredUseless
      HactiveSupport.full_const_get("MCU").should == HactiveSupport::MemoizeConsideredUseless
    end
  end

end
