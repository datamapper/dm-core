require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Property do
  before :all do
    class Zoo
      include DataMapper::Resource
    end

    class Name < DataMapper::Type
      primitive String
      size 100
    end

    class Tomato
      include DataMapper::Resource
    end
  end

  before do
    @property = DataMapper::Property.new(Zoo, :name, String, :default => 'San Diego')
  end

  it 'should provide .new' do
    DataMapper::Property.should respond_to(:new)
  end

  describe '.new' do
    [ Float, BigDecimal ].each do |primitive|
      describe "with a #{primitive} primitive" do
        it 'should raise an ArgumentError if precision is equal to or less than 0' do
          lambda{
            DataMapper::Property.new(Zoo, :test, primitive, :precision => 0)
          }.should raise_error(ArgumentError)

          lambda{
            DataMapper::Property.new(Zoo, :test, primitive, :precision => -1)
          }.should raise_error(ArgumentError)
        end

        it 'should raise an ArgumentError if scale is less than 0' do
          lambda{
            DataMapper::Property.new(Zoo, :test, primitive, :scale => -1)
          }.should raise_error(ArgumentError)
        end

        it 'should raise an ArgumentError if precision is less than scale' do
          lambda{
            DataMapper::Property.new(Zoo, :test, primitive, :precision => 1, :scale => 2)
          }.should raise_error(ArgumentError)
        end
      end
    end
  end

  it 'should provide #field' do
    @property.should respond_to(:field)
  end

  describe '#field' do
    it 'should accept a custom field' do
      property = DataMapper::Property.new(Zoo, :location, String, :field => 'City')
      property.field.should == 'City'
    end

    it 'should use repository name if passed in' do
      @property.field(:default).should == 'name'
    end

    it 'should return default field if no repository name passed in' do
      @property.field.should == 'name'
    end
  end

  it 'should provide #get' do
    @property.should respond_to(:get)
  end

  describe '#get' do
    before do
      @original_values = {}
      @resource        = mock('resource', :kind_of? => true, :new_record? => true, :original_values => @original_values)
    end

    describe 'when setting the default on initial access' do
      before do
        # make sure there was no original value
        @original_values.should_not have_key(:name)

        # force the default to be set
        @resource.should_receive(:instance_variable_get).with('@name').twice.and_return(nil)
        @resource.should_receive(:attribute_loaded?).with(:name).and_return(false)
      end

      it 'should set the ivar to the default' do
        @resource.should_receive(:instance_variable_set).with('@name', 'San Diego')

        @property.get(@resource).should == 'San Diego'
      end

      it 'should set the original value to nil' do
        @property.get(@resource).should == 'San Diego'

        @original_values.should == { :name => nil }
      end
    end
  end

  it 'should provide #get!' do
    @property.should respond_to(:get!)
  end

  describe '#get!' do
    it 'should get the resource instance variable' do
      resource = mock('resource', :kind_of? => true)
      resource.should_receive(:instance_variable_get).with('@name').and_return('Portland Zoo')
      @property.get!(resource).should == 'Portland Zoo'
    end
  end

  it 'should provide #set' do
    @property.should respond_to(:set)
  end

  describe '#set' do
    before do
      @original_values = {}
      @resource        = mock('resource', :kind_of? => true, :original_values => @original_values, :new_record? => true)
    end

    it 'should typecast the value' do
      @property.should_receive(:typecast).with(888)
      @property.set(@resource, 888)
    end
  end

  it 'should provide #set!' do
    @property.should respond_to(:set!)
  end

  describe '#set!' do
    it 'should set the resource instance variable' do
      resource = mock('resource', :kind_of? => true)
      resource.should_receive(:instance_variable_set).with('@name', 'Seattle Zoo').and_return(resource)
      @property.set!(resource, 'Seattle Zoo').object_id.should == resource.object_id
    end
  end

  it "should evaluate two similar properties as equal" do
    p1 = DataMapper::Property.new(Zoo, :name, String, { :size => 30 })
    p2 = DataMapper::Property.new(Zoo, :name, String, { :size => 30 })
    p3 = DataMapper::Property.new(Zoo, :title, String, { :size => 30 })
    p1.eql?(p2).should == true
    p1.hash.should == p2.hash
    p1.eql?(p3).should == false
    p1.hash.should_not == p3.hash
  end

  it "should create a String property" do
    property = DataMapper::Property.new(Zoo, :name, String, { :size => 30 })

    property.primitive.should == String
  end

  it "should not have key that is lazy" do
    property = DataMapper::Property.new(Zoo, :id, DataMapper::Types::Text, { :key => true })
    property.lazy?.should == false
  end

  it "should use a custom type Name property" do
    class Name < DataMapper::Type
      primitive String
    end

    property = DataMapper::Property.new(Zoo, :name, Name, {})

    property.primitive.should == String
    property.type.should == Name
    property.primitive.should == property.type.primitive
  end

  it "should override type options with property options" do
    property = DataMapper::Property.new(Zoo, :name, Name, { :size => 50 })
    options = property.instance_variable_get(:@options)

    options[:size].should == 50
  end

  it "should determine nullness" do
    DataMapper::Property.new(Tomato,:botanical_name,String,{:nullable => true}).options[:nullable].should == true
  end

  it "should determine its name"  do
    DataMapper::Property.new(Tomato,:botanical_name,String,{}).name.should == :botanical_name
  end

  it "should determine laziness" do
    DataMapper::Property.new(Tomato,:botanical_name,String,{:lazy => true}).lazy?.should == true
    DataMapper::Property.new(Tomato,:seedless,TrueClass,{}).lazy?.should == false
  end

  it "should automatically set laziness to true on text fields?" do
    DataMapper::Property.new(Tomato,:botanical_name,DataMapper::Types::Text,{}).lazy?.should == true
  end

  it "should determine whether it is a key" do
    DataMapper::Property.new(Tomato,:id,Integer,{:key => true}).key?.should == true
    DataMapper::Property.new(Tomato,:botanical_name,String,{}).key?.should == false
  end

  it "should determine whether it is serial" do
    DataMapper::Property.new(Tomato,:id,Integer,{:serial => true}).serial?.should == true
    DataMapper::Property.new(Tomato,:botanical_name,String,{}).serial?.should == false
  end

  it "should determine a default value" do
    resource = mock('resource')
    property = DataMapper::Property.new(Tomato, :botanical_name, String, :default => 'Tomato')
    property.default_for(resource).should == 'Tomato'
  end

  describe "reader and writer visibility" do
    # parameter passed to Property.new                    # reader | writer visibility
    {
      {}                                                 => [:public,    :public],
      { :accessor => :public }                           => [:public,    :public],
      { :accessor => :protected }                        => [:protected, :protected],
      { :accessor => :private }                          => [:private,   :private],
      { :reader => :public }                             => [:public,    :public],
      { :reader => :protected }                          => [:protected, :public],
      { :reader => :private }                            => [:private,   :public],
      { :writer => :public }                             => [:public,    :public],
      { :writer => :protected }                          => [:public,    :protected],
      { :writer => :private }                            => [:public,    :private],
      { :reader => :public, :writer => :public }         => [:public,    :public],
      { :reader => :public, :writer => :protected }      => [:public,    :protected],
      { :reader => :public, :writer => :private }        => [:public,    :private],
      { :reader => :protected, :writer => :public }      => [:protected, :public],
      { :reader => :protected, :writer => :protected }   => [:protected, :protected],
      { :reader => :protected, :writer => :private }     => [:protected, :private],
      { :reader => :private, :writer => :public }        => [:private,   :public],
      { :reader => :private, :writer => :protected }     => [:private,   :protected],
      { :reader => :private, :writer => :private }       => [:private,   :private],
    }.each do |input, output|
      it "#{input.inspect} should make reader #{output[0]} and writer #{output[1]}" do
        property = DataMapper::Property.new(Tomato, :botanical_name, String, input)
        property.reader_visibility.should == output[0]
        property.writer_visibility.should == output[1]
      end
    end

    [
      { :accessor => :junk },
      { :reader   => :junk },
      {                          :writer => :junk },
      { :reader   => :public,    :writer => :junk },
      { :reader   => :protected, :writer => :junk },
      { :reader   => :private,   :writer => :junk },
      { :reader   => :junk,      :writer => :public },
      { :reader   => :junk,      :writer => :protected },
      { :reader   => :junk,      :writer => :private },
      { :reader   => :junk,      :writer => :junk },
      { :reader   => :junk,      :writer => :junk },
      { :reader   => :junk,      :writer => :junk },
    ].each do |input|
      it "#{input.inspect} should raise ArgumentError" do
        lambda {
          property = DataMapper::Property.new(Tomato, :family, String, input)
        }.should raise_error(ArgumentError)
      end
    end
  end

  it "should return an instance variable name" do
   DataMapper::Property.new(Tomato, :flavor, String, {}).instance_variable_name.should == '@flavor'
   DataMapper::Property.new(Tomato, :ripe, TrueClass, {}).instance_variable_name.should == '@ripe' #not @ripe?
  end

  it "should append ? to TrueClass property reader methods" do
    class Potato
      include DataMapper::Resource
      property :id, Integer, :key => true
      property :fresh, TrueClass
      property :public, TrueClass
    end

    Potato.new().should respond_to(:fresh)
    Potato.new().should respond_to(:fresh?)

    Potato.new(:fresh => true).should be_fresh

    Potato.new().should respond_to(:public)
    Potato.new().should respond_to(:public?)
  end

  it "should move unknown options into Property#extra_options" do
    d = DataMapper::Property.new(Tomato,:botanical_name,String,{:foo=>:bar})
    d.extra_options.should == {:foo => :bar}
  end

  it 'should return the attribute value from a given instance' do
    class Tomato
      include DataMapper::Resource
      property :id, Integer, :key => true
    end

    tomato = Tomato.new(:id => 1)
    tomato.model.properties(:default)[:id].get(tomato).should == 1
  end

  it 'should set the attribute value in a given instance' do
    tomato = Tomato.new
    tomato.model.properties(:default)[:id].set(tomato, 2)
    tomato.id.should == 2
  end

  it 'should provide #custom?' do
    DataMapper::Property.new(Zoo, :name, Name, { :size => 50 }).should be_custom
    DataMapper::Property.new(Zoo, :state, String, { :size => 2 }).should_not be_custom
  end

  it "should set the field to the correct field_naming_convention" do
    DataMapper::Property.new(Zoo, :species, String, {}).field(:default).should == 'species'
    DataMapper::Property.new(Tomato, :genetic_history, DataMapper::Types::Text, {}).field(:default).should == "genetic_history"
  end

  it "should provide the primitive mapping" do
    DataMapper::Property.new(Zoo, :poverty, String, {}).primitive.should == String
    DataMapper::Property.new(Zoo, :fortune, DataMapper::Types::Text, {}).primitive.should == String
  end

  it "should provide a size/length" do
    DataMapper::Property.new(Zoo, :cleanliness, String, { :size => 100 }).size.should == 100
    DataMapper::Property.new(Zoo, :cleanliness, String, { :length => 200 }).size.should == 200
    DataMapper::Property.new(Zoo, :cleanliness, String, { :size => (0..100) }).size.should == 100
    DataMapper::Property.new(Zoo, :cleanliness, String, { :length => (0..200) }).size.should == 200
  end

  it 'should provide #typecast' do
    DataMapper::Property.new(Zoo, :name, String).should respond_to(:typecast)
  end

  describe '#typecast' do
    def self.format(value)
      case value
        when BigDecimal             then "BigDecimal(#{value.to_s('F').inspect})"
        when Float, Integer, String then "#{value.class}(#{value.inspect})"
        else value.inspect
      end
    end

    it 'should pass through the value if it is the same type when typecasting' do
      value = 'San Diego'
      property = DataMapper::Property.new(Zoo, :name, String)
      property.typecast(value).object_id.should == value.object_id
    end

    it 'should pass through the value nil when typecasting' do
      property = DataMapper::Property.new(Zoo, :string, String)
      property.typecast(nil).should == nil
    end

    it 'should pass through the value for an Object property' do
      value = 'a ruby object'
      property = DataMapper::Property.new(Zoo, :object, Object)
      property.typecast(value).object_id.should == value.object_id
    end

    [ true, 'true', 'TRUE', 1, '1', 't', 'T' ].each do |value|
      it "should typecast #{value.inspect} to true for a TrueClass property" do
        property = DataMapper::Property.new(Zoo, :true_class, TrueClass)
        property.typecast(value).should == true
      end
    end

    [ false, 'false', 'FALSE', 0, '0', 'f', 'F' ].each do |value|
      it "should typecast #{value.inspect} to false for a Boolean property" do
        property = DataMapper::Property.new(Zoo, :true_class, TrueClass)
        property.typecast(value).should == false
      end
    end

    it 'should typecast nil to nil for a Boolean property' do
      property = DataMapper::Property.new(Zoo, :true_class, TrueClass)
      property.typecast(nil).should == nil
    end

    it 'should typecast "0" to "0" for a String property' do
      property = DataMapper::Property.new(Zoo, :string, String)
      property.typecast(0).should == '0'
    end

    { '0' => 0.0, '0.0' => 0.0, 0 => 0.0, 0.0 => 0.0, BigDecimal('0.0') => 0.0 }.each do |value,expected|
      it "should typecast #{format(value)} to #{format(expected)} for a Float property" do
        property = DataMapper::Property.new(Zoo, :float, Float)
        property.typecast(value).should == expected
      end
    end

    { '-8' => -8, '-8.0' => -8, -8 => -8, -8.0 => -8, BigDecimal('8.0') => 8 }.each do |value,expected|
      it "should typecast #{format(value)} to #{format(expected)} for an Integer property" do
        property = DataMapper::Property.new(Zoo, :integer, Integer)
        property.typecast(value).should == expected
      end
    end

    { '0' => 0, '0.0' => 0, 0 => 0, 0.0 => 0, BigDecimal('0.0') => 0 }.each do |value,expected|
      it "should typecast #{format(value)} to #{format(expected)} for an Integer property" do
        property = DataMapper::Property.new(Zoo, :integer, Integer)
        property.typecast(value).should == expected
      end
    end

    { '5' => 5, '5.0' => 5, 5 => 5, 5.0 => 5, BigDecimal('5.0') => 5 }.each do |value,expected|
      it "should typecast #{format(value)} to #{format(expected)} for an Integer property" do
        property = DataMapper::Property.new(Zoo, :integer, Integer)
        property.typecast(value).should == expected
      end
    end

    { 'none' => nil, 'almost 5' => nil, '-3 change' => -3, '9 items' => 9 }.each do |value,expected|
      it "should typecast #{format(value)} to #{format(expected)} for an Integer property" do
        property = DataMapper::Property.new(Zoo, :integer, Integer)
        property.typecast(value).should == expected
      end
    end

    { '0' => BigDecimal('0'), '0.0' => BigDecimal('0.0'), 0.0 => BigDecimal('0.0'), BigDecimal('0.0') => BigDecimal('0.0') }.each do |value,expected|
      it "should typecast #{format(value)} to #{format(expected)} for a BigDecimal property" do
        property = DataMapper::Property.new(Zoo, :big_decimal, BigDecimal)
        property.typecast(value).should == expected
      end
    end

    it 'should typecast value for a DateTime property' do
      property = DataMapper::Property.new(Zoo, :date_time, DateTime)
      property.typecast('2000-01-01 00:00:00').should == DateTime.new(2000, 1, 1, 0, 0, 0)
    end

    it 'should typecast value for a Date property' do
      property = DataMapper::Property.new(Zoo, :date, Date)
      property.typecast('2000-01-01').should == Date.new(2000, 1, 1)
    end

    it 'should typecast value for a Time property' do
      property = DataMapper::Property.new(Zoo, :time, Time)
      property.typecast('2000-01-01 01:01:01.123456').should == Time.local(2000, 1, 1, 1, 1, 1, 123456)
    end

    it 'should typecast Hash for a Time property' do
      property = DataMapper::Property.new(Zoo, :time, Time)
      property.typecast(
        :year => 2002, "month" => 1, :day => 1, "hour" => 12, :min => 0, :sec => 0
      ).should == Time.local(2002, 1, 1, 12, 0, 0)
    end

    it 'should typecast Hash for a Date property' do
      property = DataMapper::Property.new(Zoo, :date, Date)
      property.typecast(:year => 2002, "month" => 1, :day => 1).should == Date.new(2002, 1, 1)
    end

    it 'should typecast Hash for a DateTime property' do
      property = DataMapper::Property.new(Zoo, :date_time, DateTime)
      property.typecast(
        :year => 2002, :month => 1, :day => 1, "hour" => 12, :min => 0, "sec" => 0
      ).should == DateTime.new(2002, 1, 1, 12, 0, 0)
    end

    it 'should use now as defaults for missing parts of a Hash to Time typecast' do
      now = Time.now
      property = DataMapper::Property.new(Zoo, :time, Time)
      property.typecast(
        :month => 1, :day => 1
      ).should == Time.local(now.year, 1, 1, now.hour, now.min, now.sec)
    end

    it 'should use now as defaults for missing parts of a Hash to Date typecast' do
      now = Time.now
      property = DataMapper::Property.new(Zoo, :date, Date)
      property.typecast(
        :month => 1, :day => 1
      ).should == Date.new(now.year, 1, 1)
    end

    it 'should use now as defaults for missing parts of a Hash to DateTime typecast' do
      now = Time.now
      property = DataMapper::Property.new(Zoo, :date_time, DateTime)
      property.typecast(
        :month => 1, :day => 1
      ).should == DateTime.new(now.year, 1, 1, now.hour, now.min, now.sec)
    end

    it 'should rescue after trying to typecast an invalid Date value from a hash' do
      property = DataMapper::Property.new(Zoo, :date, Date)
      property.typecast(:year => 2002, :month => 2, :day => 31).should == Date.new(2002, 3, 3)
    end

    it 'should rescue after trying to typecast an invalid DateTime value from a hash' do
      property = DataMapper::Property.new(Zoo, :date_time, DateTime)
      property.typecast(
        :year => 2002, :month => 2, :day => 31, :hour => 12, :min => 0, :sec => 0
      ).should == DateTime.new(2002, 3, 3, 12, 0, 0)
    end

    it 'should typecast value for a Class property' do
      property = DataMapper::Property.new(Zoo, :class, Class)
      property.typecast('Zoo').should == Zoo
    end
  end

  it 'should provide #inspect' do
    DataMapper::Property.new(Zoo, :name, String).should respond_to(:inspect)
  end

  it 'should return an abbreviated representation of the property when inspected' do
    DataMapper::Property.new(Zoo, :name, String).inspect.should == '#<Property:Zoo:name>'
  end
end
