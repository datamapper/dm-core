require 'spec_helper'

describe DataMapper::Model::Property do
  before do
    Object.send(:remove_const, :ModelPropertySpecs) if defined?(ModelPropertySpecs)
    class ::ModelPropertySpecs
      include DataMapper::Resource

      property :id, Serial
    end
    DataMapper.finalize
  end

  describe '#property' do

    subject { ModelPropertySpecs.property(:name, String) }

    it 'should define a name accessor' do
      ModelPropertySpecs.should_not be_method_defined(:name)
      subject
      ModelPropertySpecs.should be_method_defined(:name)
    end

    it 'should define a name= mutator' do
      ModelPropertySpecs.should_not be_method_defined(:name=)
      subject
      ModelPropertySpecs.should be_method_defined(:name=)
    end

    it 'should raise an exception if the method exists' do
      lambda {
        ModelPropertySpecs.property(:key, String)
      }.should raise_error(ArgumentError, '+name+ was :key, which cannot be used as a property name since it collides with an existing method or a query option')
    end

    it 'should raise an exception if the name is the same as one of the query options' do
      lambda {
        ModelPropertySpecs.property(:order, String)
      }.should raise_error(ArgumentError, '+name+ was :order, which cannot be used as a property name since it collides with an existing method or a query option')
    end
  end
end
