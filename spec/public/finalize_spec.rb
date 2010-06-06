require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper do
  describe '.finalize' do
    subject { DataMapper.finalize }

    it 'should not raise with valid models' do
      class ::ValidObject
        include DataMapper::Resource
        property :id, Integer, :key => true
      end
      method(:subject).should_not raise_error
      DataMapper::Model.descendants.delete(ValidObject)
      Object.send(:remove_const, :ValidObject)
    end

    it 'should raise on an anonymous model' do
      model = Class.new do
        include DataMapper::Resource
        property :id, Integer, :key => true
      end
      method(:subject).should raise_error(DataMapper::IncompleteModelError, "#{model.inspect} must have a name")
      DataMapper::Model.descendants.delete(model)
    end

    it 'should raise on an empty model' do
      class ::EmptyObject
        include DataMapper::Resource
      end
      method(:subject).should raise_error(DataMapper::IncompleteModelError, 'EmptyObject must have at least one property or many to one relationship to be valid')
      DataMapper::Model.descendants.delete(EmptyObject)
      Object.send(:remove_const, :EmptyObject)
    end

    it 'should raise on a keyless model' do
      class ::KeylessObject
        include DataMapper::Resource
        property :name, String
      end
      method(:subject).should raise_error(DataMapper::IncompleteModelError, 'KeylessObject must have a key to be valid')
      DataMapper::Model.descendants.delete(KeylessObject)
      Object.send(:remove_const, :KeylessObject)
    end
  end
end
