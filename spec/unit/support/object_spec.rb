require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe Object do

  it "should be able to get a recursive constant" do
    find_const('DataMapper::Resource').should == DataMapper::Resource
  end

  it "should ignore get Constants from the Kernel namespace correctly" do
    find_const('::DataMapper::Resource').should == ::DataMapper::Resource
  end

  it "should not cache unresolvable class string" do
    lambda { find_const('Foo::Bar::Baz') }.should raise_error(NameError)
    Object::NESTED_CONSTANTS.has_key?('Foo::Bar::Baz').should == false
  end

end
