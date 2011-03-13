require 'spec_helper'
require 'dm-core/support/ext/object'

describe DataMapper::Ext::Object do
  before :all do
    Object.send(:remove_const, :HactiveSupport) if defined?(HactiveSupport)
    module ::HactiveSupport
      class MemoizeConsideredUseless; end
    end

    Object.send(:remove_const, :Foo) if defined?(Foo)
    module ::Foo
      class Bar; end
    end

    Object.send(:remove_const, :Oi) if defined?(Oi)
    class ::Oi
      attr_accessor :foo
    end
  end

  describe ".full_const_get" do
    it 'returns constant by FQ name in receiver namespace' do
      DataMapper::Ext::Object.full_const_get("Oi").should == Oi
      DataMapper::Ext::Object.full_const_get("Foo::Bar").should == Foo::Bar
    end
  end

  describe ".full_const_set" do
    it 'sets constant value by FQ name in receiver namespace' do
      DataMapper::Ext::Object.full_const_set("HactiveSupport::MCU", HactiveSupport::MemoizeConsideredUseless)

      DataMapper::Ext::Object.full_const_get("HactiveSupport::MCU").should == HactiveSupport::MemoizeConsideredUseless
      DataMapper::Ext::Object.full_const_get(HactiveSupport, "MCU").should == HactiveSupport::MemoizeConsideredUseless
    end
  end

end
