require File.join(File.dirname(__FILE__), '..', 'lib', 'data_mapper', 'naming_conventions')

describe "DataMapper::NamingConventions" do
  it "should coerce a string into the convention" do
    DataMapper::NamingConventions::Underscored.call('User').should == 'user'
    DataMapper::NamingConventions::UnderscoredAndPluralized.call('User').should == 'users'
  end
end