require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper do
  describe '.setup' do
    it "should not raise with valid models" do
      class ::ValidObject
        include DataMapper::Resource
        property :id, Integer, :key => true
      end
      lambda { DataMapper.finalize }.should_not raise_error
      DataMapper::Model.descendants.delete(ValidObject)
      Object.send(:remove_const, :ValidObject)
    end

    it "should raise on an empty model" do
      class ::EmptyObject
        include DataMapper::Resource
      end
      lambda { DataMapper.finalize }.should raise_error
      DataMapper::Model.descendants.delete(EmptyObject)
      Object.send(:remove_const, :EmptyObject)
    end

    it "should raise on a keyless model" do
      class ::KeylessObject
        include DataMapper::Resource
        property :name, String
      end
      lambda { DataMapper.finalize }.should raise_error
      DataMapper::Model.descendants.delete(KeylessObject)
      Object.send(:remove_const, :KeylessObject)
    end
  end
end
