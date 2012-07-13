require 'spec_helper'
require 'dm-core/support/inflector/inflections'

describe DataMapper::Inflector do

  it "should singularize 'status' correctly" do
    DataMapper::Inflector.singularize('status').should == 'status'
    DataMapper::Inflector.singularize('status').should_not == 'statu'
  end

  it "should singularize 'alias' correctly" do
    DataMapper::Inflector.singularize('alias').should == 'alias'
    DataMapper::Inflector.singularize('alias').should_not eq 'alia'
  end

end
