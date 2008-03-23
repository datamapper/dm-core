require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe DataMapper::Repository do

  
  it "should provide persistance methods" do
    repository.should respond_to(:get)
    repository.should respond_to(:first)
    repository.should respond_to(:all)
    repository.should respond_to(:save)
    repository.should respond_to(:destroy)
  end

  
end