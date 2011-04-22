require 'spec_helper'

shared_examples_for "a correct property declaration" do
  it 'should define a name accessor' do
    @model.should_not be_method_defined(@property_name)
    subject
    @model.should be_method_defined(@property_name)
  end

  it 'should define a name= mutator' do
    @model.should_not be_method_defined(:"#{@property_name}=")
    subject
    @model.should be_method_defined(:"#{@property_name}=")
  end
end

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
    context "using default repository" do
      before do
        Object.send(:remove_const, :UserDefault) if defined?(::UserDefault)

        class ::UserDefault
          include DataMapper::Resource
          property :id, Serial
        end

        @model         = ::UserDefault
        @property_name = :name
      end

      subject do
        ::UserDefault.property(:name, String)
      end

      it_should_behave_like "a correct property declaration"
    end

    context "using alternate repository" do
      before do
        Object.send(:remove_const, :UserAlternate) if defined?(::UserAlternate)

        class ::UserAlternate
          include DataMapper::Resource
          property :id, Serial
          repository(:alternate) { property :age, Integer }
        end

        @model         = UserAlternate
        @property_name = :alt_name
      end

      subject do
        ::UserAlternate.property(:alt_name, String)
      end

      it_should_behave_like "a correct property declaration"
    end

    it 'should raise an exception if the method exists' do
      lambda {
        ModelPropertySpecs.property(:key, String)
      }.should raise_error(ArgumentError, '+name+ was :key, which cannot be used as a property name since it collides with an existing method or a query option')
    end

    it 'should raise an exception if the property is boolean and method with question mark already exists' do
      lambda {
        ModelPropertySpecs.property(:destroyed, DataMapper::Property::Boolean)
      }.should raise_error(ArgumentError, '+name+ was :destroyed, which cannot be used as a property name since it collides with an existing method or a query option')
    end

    it 'should raise an exception if the name is the same as one of the query options' do
      lambda {
        ModelPropertySpecs.property(:order, String)
      }.should raise_error(ArgumentError, '+name+ was :order, which cannot be used as a property name since it collides with an existing method or a query option')
    end
  end
end
