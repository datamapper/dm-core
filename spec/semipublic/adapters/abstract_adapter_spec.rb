require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'AbstractAdapter' do
  before :all do
    @adapter = DataMapper::Adapters::AbstractAdapter.new(:abstract, :foo => 'bar')
    @adapter_class = @adapter.class
    @scheme        = Extlib::Inflection.underscore(Extlib::Inflection.demodulize(@adapter_class).chomp('Adapter'))
    @adapter_name  = "test_#{@scheme}".to_sym
  end

  describe 'initialization' do

    describe 'name' do
      it 'should have a name' do
        @adapter.name.should == :abstract
      end
    end

    it 'should set options' do
      @adapter.options.should == {:foo => 'bar'}
    end

    it 'should set naming conventions' do
      @adapter.resource_naming_convention.should == DataMapper::NamingConventions::Resource::UnderscoredAndPluralized
      @adapter.field_naming_convention.should    == DataMapper::NamingConventions::Field::Underscored
    end

  end

end
