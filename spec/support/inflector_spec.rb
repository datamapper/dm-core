require File.dirname(__FILE__) + "/../spec_helper"

describe Inflector do
  it "should camelize strings" do
    Inflector.camelize("data_mapper").should == "DataMapper"
    Inflector.camelize("data_mapper/support").should == "DataMapper::Support"
  end
  
  it "should pluralize strings" do
    Inflector.pluralize("post").should == "posts"
    Inflector.pluralize("octopus").should == "octopi"
    Inflector.pluralize("sheep").should == "sheep"
    Inflector.pluralize("word").should == "words"
    Inflector.pluralize("the blue mailman").should == "the blue mailmen"
    Inflector.pluralize("CamelOctopus").should == "CamelOctopi"
  end
  
  it "should singularize strings" do
    Inflector.singularize("posts").should == "post"
    Inflector.singularize("octopi").should == "octopus"
    Inflector.singularize("sheep").should == "sheep"
    Inflector.singularize("word").should == "word"
    Inflector.singularize("the blue mailmen").should == "the blue mailman"
    Inflector.singularize("CamelOctopi").should == "CamelOctopus"
  end
  
  it "should demodulize strings" do
    Inflector.demodulize("DataMapper::Support").should == "Support"
  end
  
  it "should create foreign keys from class names and key names" do
    Inflector.foreign_key("Animal").should == "animal_id"
    Inflector.foreign_key("Admin::Post").should == "post_id"
    Inflector.foreign_key("Animal", "name").should == "animal_name"
  end
  
  it "should constantize strings" do
    Inflector.constantize("Class").should == Class
    lambda { Inflector.constantize("asdf") }.should raise_error
  end
end
