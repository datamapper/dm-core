require 'spec_helper'

describe DataMapper::Property::Class do
  before :all do
    Object.send(:remove_const, :Foo) if defined?(Foo)
    Object.send(:remove_const, :Bar) if defined?(Bar)

    class ::Foo; end
    class ::Bar; end

    @name          = :type
    @type          = described_class
    @value         = Foo
    @other_value   = Bar
    @invalid_value = 1
  end

  it_should_behave_like 'A semipublic Property'

  describe '#typecast_to_primitive' do
    it 'returns same value if a class' do
      @property.typecast(@model).should equal(@model)
    end

    it 'returns the class if found' do
      @property.typecast(@model.name).should eql(@model)
    end

    it 'does not typecast non-class values' do
      @property.typecast('NoClass').should eql('NoClass')
    end
  end
end
