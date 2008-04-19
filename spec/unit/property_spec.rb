require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe DataMapper::Property do

  before(:all) do
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

  it "should determine lazyness" do
    DataMapper::Property.new(Tomato,:botanical_name,String,{:lazy => true}).lazy?.should == true
    DataMapper::Property.new(Tomato,:seedless,TrueClass,{}).lazy?.should == false
  end

  it "should automatically set lazyness to true on text fields?" do
    DataMapper::Property.new(Tomato,:botanical_name,DataMapper::Types::Text,{}).lazy?.should == true
  end

  it "should determine keyness" do
    DataMapper::Property.new(Tomato,:id,Fixnum,{:key => true}).key?.should == true
    DataMapper::Property.new(Tomato,:botanical_name,String,{}).key?.should == false
  end

  it "should determine serialness" do
    DataMapper::Property.new(Tomato,:id,Fixnum,{:serial => true}).serial?.should == true
    DataMapper::Property.new(Tomato,:botanical_name,String,{}).serial?.should == false
  end

  it "should determine lockability" do
    DataMapper::Property.new(Tomato, :id, Fixnum, { :lock => true }).lock?.should == true
    DataMapper::Property.new(Tomato, :botanical_name, String, {}).lock?.should == false
  end

  # TODO should we add an accessor method property.default_value
  it "should determine a default value" do
    DataMapper::Property.new(Tomato,:botanical_name,String,{:default => 'Tomato'}).options[:default].should == 'Tomato'
  end

  it "should determine visibility of readers and writers" do
    name = DataMapper::Property.new(Tomato,:botanical_name,String,{})
    name.reader_visibility.should == :public
    name.writer_visibility.should == :public

    seeds = DataMapper::Property.new(Tomato,:seeds,TrueClass,{:accessor=>:private})
    seeds.reader_visibility.should == :private
    seeds.writer_visibility.should == :private

    family = DataMapper::Property.new(Tomato,:family,String,{:reader => :public, :writer => :private })
    family.reader_visibility.should == :public
    family.writer_visibility.should == :private
  end

  it "should return an instance variable name" do
   DataMapper::Property.new(Tomato,:flavor,String,{}).instance_variable_name.should == '@flavor'
   DataMapper::Property.new(Tomato,:ripe,TrueClass,{}).instance_variable_name.should == '@ripe' #not @ripe?
  end

  it "should append ? to TrueClass property reader methods" do
    class Potato
      include DataMapper::Resource
      property :fresh, TrueClass
    end
    Potato.new().should respond_to(:fresh?)
    Potato.new(:fresh => true).should be_true
  end

  it "should raise an ArgumentError when created with an invalid option" do
    lambda{
      DataMapper::Property.new(Tomato,:botanical_name,String,{:foo=>:bar})
    }.should raise_error(ArgumentError)
  end

  it 'should return the attribute value from a given instance' do
    class Tomahto
      include DataMapper::Resource
      property :id, Fixnum, :key => true
    end

    tomato = Tomahto.new(:id => 1)
    tomato.class.properties(:default)[:id].get(tomato).should == 1
  end

  it 'should set the attribute value in a given instance' do
    tomato = Tomahto.new
    tomato.class.properties(:default)[:id].set(2, tomato)
    tomato.id.should == 2
  end

  it 'should respond to custom?' do
    DataMapper::Property.new(Zoo, :name, Name, { :size => 50 }).should be_custom
    DataMapper::Property.new(Zoo, :state, String, { :size => 2 }).should_not be_custom
  end

  it "should set the field to the correct field_naming_convention" do
    DataMapper::Property.new(Zoo, :species, String, {}).field.should == 'species'
    DataMapper::Property.new(Tomato, :genetic_history, DataMapper::Types::Text, {}).field.should == "genetic_history"
  end

  it "should provide the primitive mapping" do
    DataMapper::Property.new(Zoo, :poverty, String, {}).primitive.should == String
    DataMapper::Property.new(Zoo, :fortune, DataMapper::Types::Text, {}).primitive.should == String
  end

  it 'should provide typecast' do
    DataMapper::Property.new(Zoo, :name, String).should respond_to(:typecast)
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

  it 'should typecast value (true) for a TrueClass property' do
    property = DataMapper::Property.new(Zoo, :true_class, TrueClass)
    property.typecast(true).should == true
  end

  it 'should typecast value ("true") for a TrueClass property' do
    property = DataMapper::Property.new(Zoo, :true_class, TrueClass)
    property.typecast('true').should == true
  end

  it 'should typecast value for a String property' do
    property = DataMapper::Property.new(Zoo, :string, String)
    property.typecast(0).should == '0'
  end

  it 'should typecast value for a Float property' do
    property = DataMapper::Property.new(Zoo, :float, Float)
    property.typecast('0.0').should == 0.0
  end

  it 'should typecast value for a Fixnum property' do
    property = DataMapper::Property.new(Zoo, :fixnum, Fixnum)
    property.typecast('0').should == 0
  end

  it 'should typecast value for a BigDecimal property' do
    property = DataMapper::Property.new(Zoo, :big_decimal, BigDecimal)
    property.typecast(0.0).should == BigDecimal.new('0.0')
  end

  it 'should typecast value for a DateTime property' do
    property = DataMapper::Property.new(Zoo, :date_time, DateTime)
    property.typecast('2000-01-01 00:00:00').should == DateTime.new(2000, 1, 1, 0, 0, 0)
  end

  it 'should typecast value for a Date property' do
    property = DataMapper::Property.new(Zoo, :date, Date)
    property.typecast('2000-01-01').should == Date.new(2000, 1, 1)
  end

  it 'should typecast value for a Class property' do
    property = DataMapper::Property.new(Zoo, :class, Class)
    property.typecast('Zoo').should == Zoo
  end

  it 'should pass through the value for an Object property' do
    value = 'a ruby object'
    property = DataMapper::Property.new(Zoo, :object, Object)
    property.typecast(value).object_id.should == value.object_id
  end

  it 'should provide inspect' do
    DataMapper::Property.new(Zoo, :name, String).should respond_to(:inspect)
  end

  it 'should return an abbreviated representation of the property when inspected' do
    DataMapper::Property.new(Zoo, :name, String).inspect.should == '#<Property:Zoo:name>'
  end

  it 'should raise a SyntaxError when the name contains invalid characters' do
    lambda { DataMapper::Property.new(Zoo, :"with space", TrueClass) }.should raise_error(SyntaxError)
  end
end
