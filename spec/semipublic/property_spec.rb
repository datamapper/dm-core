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
        @property.options.should == {}
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
            @property.options.should == options
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

        property :id,         Integer, :key => true
        property :name,       String
        property :rating,     Float
        property :rate,       BigDecimal
        property :type,       Class
        property :alias,      String
        property :active,     Boolean
        property :deleted_at, Time
        property :created_at, DateTime
        property :created_on, Date
      end
    end

    @model = Blog::Author
  end

  describe '#typecast' do
    describe "when type is able to do typecasting on it's own" do
      it 'delegates all the work to the type'
    end

    describe 'when value is nil' do
      it 'returns value unchanged' do
        @model.properties[:name].typecast(nil).should be(nil)
      end
    end

    describe 'when value is a Ruby primitive' do
      it 'returns value unchanged' do
        @model.properties[:id].typecast([3200, 2400]).should == [3200, 2400]
      end
    end

    describe 'when type primitive is a String' do
      before :all do
        @property = @model.properties[:name]
      end

      it 'returns same value if a string' do
        @value = '1.0'
        @property.typecast(@value).should equal(@value)
      end
    end

    describe 'when type primitive is a Float' do
      before :all do
        @property = @model.properties[:rating]
      end

      it 'returns same value if a float' do
        @value = 24.0
        @property.typecast(@value).should equal(@value)
      end

      it 'returns float representation of a zero string integer' do
        @property.typecast('0').should eql(0.0)
      end

      it 'returns float representation of a positive string integer' do
        @property.typecast('24').should eql(24.0)
      end

      it 'returns float representation of a negative string integer' do
        @property.typecast('-24').should eql(-24.0)
      end

      it 'returns float representation of a zero string float' do
        @property.typecast('0.0').should eql(0.0)
      end

      it 'returns float representation of a positive string float' do
        @property.typecast('24.35').should eql(24.35)
      end

      it 'returns float representation of a negative string float' do
        @property.typecast('-24.35').should eql(-24.35)
      end

      it 'returns float representation of a zero string float, with no leading digits' do
        @property.typecast('.0').should eql(0.0)
      end

      it 'returns float representation of a positive string float, with no leading digits' do
        @property.typecast('.41').should eql(0.41)
      end

      it 'returns float representation of a zero integer' do
        @property.typecast(0).should eql(0.0)
      end

      it 'returns float representation of a positive integer' do
        @property.typecast(24).should eql(24.0)
      end

      it 'returns float representation of a negative integer' do
        @property.typecast(-24).should eql(-24.0)
      end

      it 'returns float representation of a zero decimal' do
        @property.typecast(BigDecimal('0.0')).should eql(0.0)
      end

      it 'returns float representation of a positive decimal' do
        @property.typecast(BigDecimal('24.35')).should eql(24.35)
      end

      it 'returns float representation of a negative decimal' do
        @property.typecast(BigDecimal('-24.35')).should eql(-24.35)
      end

      [ Object.new, true, '00.0', '0.', '-.0', 'string' ].each do |value|
        it "does not typecast non-numeric value #{value.inspect}" do
          @property.typecast(value).should equal(value)
        end
      end
    end

    describe 'when type primitive is a Integer' do
      before :all do
        @property = @model.properties[:id]
      end

      it 'returns same value if an integer' do
        @value = 24
        @property.typecast(@value).should equal(@value)
      end

      it 'returns integer representation of a zero string integer' do
        @property.typecast('0').should eql(0)
      end

      it 'returns integer representation of a positive string integer' do
        @property.typecast('24').should eql(24)
      end

      it 'returns integer representation of a negative string integer' do
        @property.typecast('-24').should eql(-24)
      end

      it 'returns integer representation of a zero string float' do
        @property.typecast('0.0').should eql(0)
      end

      it 'returns integer representation of a positive string float' do
        @property.typecast('24.35').should eql(24)
      end

      it 'returns integer representation of a negative string float' do
        @property.typecast('-24.35').should eql(-24)
      end

      it 'returns integer representation of a zero string float, with no leading digits' do
        @property.typecast('.0').should eql(0)
      end

      it 'returns integer representation of a positive string float, with no leading digits' do
        @property.typecast('.41').should eql(0)
      end

      it 'returns integer representation of a zero float' do
        @property.typecast(0.0).should eql(0)
      end

      it 'returns integer representation of a positive float' do
        @property.typecast(24.35).should eql(24)
      end

      it 'returns integer representation of a negative float' do
        @property.typecast(-24.35).should eql(-24)
      end

      it 'returns integer representation of a zero decimal' do
        @property.typecast(BigDecimal('0.0')).should eql(0)
      end

      it 'returns integer representation of a positive decimal' do
        @property.typecast(BigDecimal('24.35')).should eql(24)
      end

      it 'returns integer representation of a negative decimal' do
        @property.typecast(BigDecimal('-24.35')).should eql(-24)
      end

      [ Object.new, true, '00.0', '0.', '-.0', 'string' ].each do |value|
        it "does not typecast non-numeric value #{value.inspect}" do
          @property.typecast(value).should equal(value)
        end
      end
    end

    describe 'when type primitive is a BigDecimal' do
      before :all do
        @property = @model.properties[:rate]
      end

      it 'returns same value if a decimal' do
        @value = BigDecimal('24.0')
        @property.typecast(@value).should equal(@value)
      end

      it 'returns decimal representation of a zero string integer' do
        @property.typecast('0').should eql(BigDecimal('0.0'))
      end

      it 'returns decimal representation of a positive string integer' do
        @property.typecast('24').should eql(BigDecimal('24.0'))
      end

      it 'returns decimal representation of a negative string integer' do
        @property.typecast('-24').should eql(BigDecimal('-24.0'))
      end

      it 'returns decimal representation of a zero string float' do
        @property.typecast('0.0').should eql(BigDecimal('0.0'))
      end

      it 'returns decimal representation of a positive string float' do
        @property.typecast('24.35').should eql(BigDecimal('24.35'))
      end

      it 'returns decimal representation of a negative string float' do
        @property.typecast('-24.35').should eql(BigDecimal('-24.35'))
      end

      it 'returns decimal representation of a zero string float, with no leading digits' do
        @property.typecast('.0').should eql(BigDecimal('0.0'))
      end

      it 'returns decimal representation of a positive string float, with no leading digits' do
        @property.typecast('.41').should eql(BigDecimal('0.41'))
      end

      it 'returns decimal representation of a zero integer' do
        @property.typecast(0).should eql(BigDecimal('0.0'))
      end

      it 'returns decimal representation of a positive integer' do
        @property.typecast(24).should eql(BigDecimal('24.0'))
      end

      it 'returns decimal representation of a negative integer' do
        @property.typecast(-24).should eql(BigDecimal('-24.0'))
      end

      it 'returns decimal representation of a zero float' do
        @property.typecast(0.0).should eql(BigDecimal('0.0'))
      end

      it 'returns decimal representation of a positive float' do
        @property.typecast(24.35).should eql(BigDecimal('24.35'))
      end

      it 'returns decimal representation of a negative float' do
        @property.typecast(-24.35).should eql(BigDecimal('-24.35'))
      end

      [ Object.new, true, '00.0', '0.', '-.0', 'string' ].each do |value|
        it "does not typecast non-numeric value #{value.inspect}" do
          @property.typecast(value).should equal(value)
        end
      end
    end

    describe 'when type primitive is a DateTime' do
      before :all do
        @property = @model.properties[:created_at]
      end

      describe 'and value given as a hash with keys like :year, :month, etc' do
        it 'builds a DateTime instance from hash values' do
          result = @property.typecast(
            'year'  => '2006',
            'month' => '11',
            'day'   => '23',
            'hour'  => '12',
            'min'   => '0',
            'sec'   => '0'
          )

          result.should be_kind_of(DateTime)
          result.year.should eql(2006)
          result.month.should eql(11)
          result.day.should eql(23)
          result.hour.should eql(12)
          result.min.should eql(0)
          result.sec.should eql(0)
        end
      end

      describe 'and value is a string' do
        it 'parses the string' do
          @property.typecast('Dec, 2006').month.should == 12
        end
      end

      it 'does not typecast non-datetime values' do
        @property.typecast('not-datetime').should eql('not-datetime')
      end
    end

    describe 'when type primitive is a Date' do
      before :all do
        @property = @model.properties[:created_on]
      end

      describe 'and value given as a hash with keys like :year, :month, etc' do
        it 'builds a Date instance from hash values' do
          result = @property.typecast(
            'year'  => '2007',
            'month' => '3',
            'day'   => '25'
          )

          result.should be_kind_of(Date)
          result.year.should eql(2007)
          result.month.should eql(3)
          result.day.should eql(25)
        end
      end

      describe 'and value is a string' do
        it 'parses the string' do
          result = @property.typecast('Dec 20th, 2006')
          result.month.should == 12
          result.day.should == 20
          result.year.should == 2006
        end
      end

      it 'does not typecast non-date values' do
        @property.typecast('not-date').should eql('not-date')
      end
    end

    describe 'when type primitive is a Time' do
      before :all do
        @property = @model.properties[:deleted_at]
      end

      describe 'and value given as a hash with keys like :year, :month, etc' do
        it 'builds a Time instance from hash values' do
          result = @property.typecast(
            'year'  => '2006',
            'month' => '11',
            'day'   => '23',
            'hour'  => '12',
            'min'   => '0',
            'sec'   => '0'
          )

          result.should be_kind_of(Time)
          result.year.should  eql(2006)
          result.month.should eql(11)
          result.day.should   eql(23)
          result.hour.should  eql(12)
          result.min.should   eql(0)
          result.sec.should   eql(0)
        end
      end

      describe 'and value is a string' do
        it 'parses the string' do
          result = @property.typecast('22:24')
          result.hour.should eql(22)
          result.min.should eql(24)
        end
      end

      it 'does not typecast non-time values' do
        pending_if 'Time#parse is too permissive', RUBY_VERSION <= '1.9.1' do
          @property.typecast('not-time').should eql('not-time')
        end
      end
    end

    describe 'when type primitive is a Class' do
      before :all do
        @property = @model.properties[:type]
      end

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

    describe 'when type primitive is a Boolean' do
      before :all do
        @property = @model.properties[:active]
      end

      [ true, 'true', 'TRUE', '1', 1, 't', 'T' ].each do |value|
        it "returns true when value is #{value.inspect}" do
          @property.typecast(value).should be_true
        end
      end

      [ false, 'false', 'FALSE', '0', 0, 'f', 'F' ].each do |value|
        it "returns false when value is #{value.inspect}" do
          @property.typecast(value).should be_false
        end
      end

      [ 'string', 2, 1.0, BigDecimal('1.0'), DateTime.now, Time.now, Date.today, Class, Object.new, ].each do |value|
        it "does not typecast value #{value.inspect}" do
          @property.typecast(value).should equal(value)
        end
      end
    end
  end

  describe '#valid?' do
    describe 'when provided a valid value' do
      it 'should return true' do
        @model.properties[:name].valid?('Dan Kubb').should be_true
      end
    end

    describe 'when provide an invalid value' do
      it 'should return false' do
        @model.properties[:name].valid?(1).should be_false
      end
    end

    describe 'when provide a nil value when required' do
      it 'should return false' do
        @model.properties[:id].valid?(nil).should be_false
      end
    end

    describe 'when provide a nil value when not required' do
      it 'should return false' do
        @model.properties[:alias].valid?(nil).should be_true
      end
    end

    describe 'when type primitive is a Boolean' do
      before do
        @property = @model.properties[:active]
      end

      [ true, false ].each do |value|
        it "returns true when value is #{value.inspect}" do
          @property.valid?(value).should be_true
        end
      end

      [ 'true', 'TRUE', '1', 1, 't', 'T', 'false', 'FALSE', '0', 0, 'f', 'F' ].each do |value|
        it "returns false for #{value.inspect}" do
          @property.valid?(value).should be_false
        end
      end
    end
  end

  describe '#value' do
    it 'returns value for core types'

    it 'triggers dump operation for custom types'
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
      @model.properties(:other)[:name].options[:field].should == 'other_name'
    end

    it 'should return property options in default repository' do
      @model.properties[:name].options[:field].should be_nil
    end
  end
end
