require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Model do
  before do
    # class EmptyModel
    #   include DataMapper::Resource

    #   property :id, Integer, :key => true
    # end
  end

  describe "#append_extensions" do
    before do
      module Extender; def foobar; end; end
      DataMapper::Model.append_extensions(Extender)

    end

    it "should append the module given when DM::Model is extended" do
      class ExtendMe
        include DataMapper::Resource
        property :id, Integer, :key => true
      end

      ExtendMe.should respond_to(:foobar)
    end

  end


end
