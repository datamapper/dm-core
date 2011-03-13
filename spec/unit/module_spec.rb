require 'spec_helper'
require 'dm-core/support/ext/module'

describe DataMapper::Ext::Module do

  before :all do
    Object.send(:remove_const, :Foo) if defined?(Foo)
    Object.send(:remove_const, :Baz) if defined?(Baz)
    Object.send(:remove_const, :Bar) if defined?(Bar)

    module ::Foo
      module ModBar
        module Noo
          module Too
            module Boo; end
          end
        end
      end

      class Zed; end
    end

    class ::Baz; end

    class ::Bar; end
  end

  it "should raise NameError for a missing constant" do
    lambda { DataMapper::Ext::Module.find_const(Foo, 'Moo') }.should raise_error(NameError)
    lambda { DataMapper::Ext::Module.find_const(Object, 'MissingConstant') }.should raise_error(NameError)
  end

  it "should be able to get a recursive constant" do
    DataMapper::Ext::Module.find_const(Object, 'Foo::ModBar').should == Foo::ModBar
  end

  it "should ignore get Constants from the Kernel namespace correctly" do
    DataMapper::Ext::Module.find_const(Object, '::Foo::ModBar').should == ::Foo::ModBar
  end

  it "should find relative constants" do
    DataMapper::Ext::Module.find_const(Foo, 'ModBar').should == Foo::ModBar
    DataMapper::Ext::Module.find_const(Foo, 'Baz').should == Baz
  end

  it "should find sibling constants" do
    DataMapper::Ext::Module.find_const(Foo::ModBar, "Zed").should == Foo::Zed
  end

  it "should find nested constants on nested constants" do
    DataMapper::Ext::Module.find_const(Foo::ModBar, 'Noo::Too').should == Foo::ModBar::Noo::Too
  end

  it "should find constants outside of nested constants" do
    DataMapper::Ext::Module.find_const(Foo::ModBar::Noo::Too, "Zed").should == Foo::Zed
  end

  it 'should be able to find past the second nested level' do
    DataMapper::Ext::Module.find_const(Foo::ModBar::Noo, 'Too').should == Foo::ModBar::Noo::Too
    DataMapper::Ext::Module.find_const(Foo::ModBar::Noo::Too, 'Boo').should == Foo::ModBar::Noo::Too::Boo
  end


  it "should be able to deal with constants being added and removed" do
    DataMapper::Ext::Module.find_const(Object, 'Bar') # First we load Bar with find_const
    Object.module_eval { remove_const('Bar') } # Now we delete it
    module ::Bar; end; # Now we redefine it
    DataMapper::Ext::Module.find_const(Object, 'Bar').should == Bar
  end

end
