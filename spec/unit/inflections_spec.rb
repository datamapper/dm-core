require 'spec_helper'
require 'dm-core/support/inflector/inflections'

describe DataMapper::Inflector do

  it "should singularize 'status' correctly" do
    DataMapper::Inflector.singularize('status').should eql 'status'
    DataMapper::Inflector.singularize('status').should_not eql 'statu'
  end

  it "should singularize 'alias' correctly" do
    DataMapper::Inflector.singularize('alias').should eql 'alias'
    DataMapper::Inflector.singularize('alias').should_not eql 'alia'
  end

end
