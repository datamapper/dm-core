require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

require __DIR__.parent + 'lib/data_mapper/naming_conventions'

describe "DataMapper::NamingConventions" do
  it "should coerce a string into the Underscored convention" do
    DataMapper::NamingConventions::Underscored.call('User').should == 'user'
    DataMapper::NamingConventions::Underscored.call('UserAccountSetting').should == 'user_account_setting'
  end
  
  it "should coerce a string into the UnderscoredAndPluralized convention" do
    DataMapper::NamingConventions::UnderscoredAndPluralized.call('User').should == 'users'
    DataMapper::NamingConventions::UnderscoredAndPluralized.call('UserAccountSetting').should == 'user_account_settings'
  end
  
  it "should coerce a string into the Yaml convention" do
    DataMapper::NamingConventions::Yaml.call('UserSetting').should == 'user_settings.yaml'
    DataMapper::NamingConventions::Yaml.call('User').should == 'users.yaml'
  end
end