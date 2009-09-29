require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# class methods
describe DataMapper::Property do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :id, Serial
      end
    end
  end

  describe '.new' do
    before :all do
      @model = Blog::Article
      @name  = :title
      @type  = String
    end

    describe 'when provided no options' do
      before :all do
        @property = DataMapper::Property.new(@model, @name, @type)
      end

      it 'should return a Property' do
        @property.should be_kind_of(DataMapper::Property)
      end

      it 'should set the model' do
        @property.model.should equal(@model)
      end

      it 'should set the type' do
        @property.type.should equal(@type)
      end

      it 'should set the options to an empty Hash' do
        @property.options.should eql({})
      end
    end

    [ :index, :unique_index, :unique, :lazy ].each do |attribute|
      [ true, false, :title, [ :title ] ].each do |value|
        describe "when provided #{(options = { attribute => value }).inspect}" do
          before :all do
            @property = DataMapper::Property.new(@model, @name, @type, options)
          end

          it 'should return a Property' do
            @property.should be_kind_of(DataMapper::Property)
          end

          it 'should set the model' do
            @property.model.should equal(@model)
          end

          it 'should set the type' do
            @property.type.should equal(@type)
          end

          it "should set the options to #{options.inspect}" do
            @property.options.should eql(options)
          end
        end
      end

      [ [], nil ].each do |value|
        describe "when provided #{(invalid_options = { attribute => value }).inspect}" do
          it 'should raise an exception' do
            lambda {
              DataMapper::Property.new(@model, @name, @type, invalid_options)
            }.should raise_error(ArgumentError, "options[#{attribute.inspect}] must be either true, false, a Symbol or an Array of Symbols")
          end
        end
      end
    end
  end
end

# instance methods
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
