require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

require __DIR__.parent + 'lib/data_mapper/naming_conventions'

describe "DataMapper::NamingConventions" do
  it "should coerce a string into the convention" do
    DataMapper::NamingConventions::Underscored.call('User').should == 'user'
    DataMapper::NamingConventions::UnderscoredAndPluralized.call('User').should == 'users'
  end
end