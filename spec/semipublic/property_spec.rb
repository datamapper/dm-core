require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Property do
  before :all do
    module ::Blog
      class Author
        include DataMapper::Resource

        property :name,  String, :key => true
        property :alias, String
      end
    end
  end

  describe '#valid?' do
    describe 'when provided a valid value' do
      it 'should return true' do
        Blog::Author.properties[:name].valid?('Dan Kubb').should be_true
      end
    end

    describe 'when provide an invalid value' do
      it 'should return false' do
        Blog::Author.properties[:name].valid?(1).should be_false
      end
    end

    describe 'when provide a nil value when not nullable' do
      it 'should return false' do
        Blog::Author.properties[:name].valid?(nil).should be_false
      end
    end

    describe 'when provide a nil value when nullable' do
      it 'should return false' do
        Blog::Author.properties[:alias].valid?(nil).should be_true
      end
    end
  end
  
  describe 'override property definition in other repository' do
    before(:all) do
      module ::Blog
        class Author
          repository(:other) do
            property :name,  String, :key => true, :field => 'other_name'
          end
        end
      end
    end
      
    it 'should return property options in other repository' do
      ::Blog::Author.properties(:other)[:name].options[:field].should == 'other_name'
    end

    it 'should return property options in default repository' do
      ::Blog::Author.properties[:name].options[:field].should be_nil
    end
  end

end
