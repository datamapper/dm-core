require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent.parent + 'spec_helper'

describe Struct do

  it "should have attributes" do

    s = Struct.new(:name).new('bob')
    s.attributes.should == { :name => 'bob' }

  end

end
