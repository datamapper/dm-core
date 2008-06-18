require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# rSpec completely FUBARs everything if you give it a Module here.
# So we give it a String of the module name instead.
# DO NOT CHANGE THIS!
describe "DataMapper::Resource" do
  before :all do
    class Planet
      include DataMapper::Resource

      storage_names[:legacy] = "dying_planets"

      property :id, Integer, :key => true
      property :name, String
      property :age, Integer
      property :core, String, :private => true
      property :type, Discriminator
      property :data, Object

      repository(:legacy) do
        property :cowabunga, String
      end

      def age
        attribute_get(:age)
      end

      def to_s
        name
      end
    end

    class Moon
    end

    class LegacyStar
      include DataMapper::Resource
      def self.default_repository_name
        :legacy
      end
    end

    class Phone
      include DataMapper::Resource

      property :name, String, :key => true
      property :awesomeness, Integer
    end

    class Fruit
      include DataMapper::Resource

      property :id, Integer, :key => true
      property :name, String
    end

    class Grain
      include DataMapper::Resource

      property :id, Serial
      property :name, String, :default => 'wheat'
    end

    class Vegetable
      include DataMapper::Resource

      property :id, Serial
      property :name, String
    end

    class Banana < Fruit
      property :type, Discriminator
    end
  end

  it 'should provide #attribute_get' do
    Planet.new.should respond_to(:attribute_get)
  end

  describe '#attribute_get' do
    it 'should delegate to Property#get' do
      planet = Planet.new
      Planet.properties[:age].should_receive(:get).with(planet).and_return(1)
      planet.age.should == 1
    end
  end

  it 'should provide #attribute_set' do
    Planet.new.should respond_to(:attribute_set)
  end

  describe '#attribute_set' do
    it 'should typecast the value' do
      Planet.properties[:age].should_receive(:typecast).with('1').and_return(1)
      planet = Planet.new
      planet.age = '1'
      planet.age.should == 1
    end

    it 'should delegate to Property#set' do
      planet = Planet.new
      Planet.properties[:age].should_receive(:set).with(planet, 1).and_return(1)
      planet.age = 1
    end
  end

  it 'should provide #save' do
    Planet.new.should respond_to(:save)
  end

  describe '#save' do
    before do
      @adapter = repository(:default).adapter
    end

    describe 'with a new resource' do
      it 'should set defaults before create' do
        resource = Grain.new

        resource.should_not be_dirty
        resource.should be_new_record
        resource.instance_variable_get('@name').should be_nil

        @adapter.should_receive(:create).with([ resource ]).and_return(1)

        resource.save.should be_true

        resource.instance_variable_get('@name').should == 'wheat'
      end

      it 'should create when dirty' do
        resource = Vegetable.new(:id => 1, :name => 'Potato')

        resource.should be_dirty
        resource.should be_new_record

        @adapter.should_receive(:create).with([ resource ]).and_return(1)

        resource.save.should be_true
      end

      it 'should create when non-dirty, and it has a serial key' do
        resource = Vegetable.new

        resource.should_not be_dirty
        resource.should be_new_record
        resource.model.key.any? { |p| p.serial? }.should be_true

        @adapter.should_receive(:create).with([ resource ]).and_return(1)

        resource.save.should be_true
      end

      it 'should not create when non-dirty, and is has a non-serial key' do
        resource = Fruit.new

        resource.should_not be_dirty
        resource.should be_new_record
        resource.model.key.any? { |p| p.serial? }.should be_false

        @adapter.should_not_receive(:create)

        resource.save.should be_false
      end
    end

    describe 'with an existing resource' do
      it 'should update' do
        resource = Vegetable.new(:name => 'Potato')
        resource.instance_variable_set('@new_record', false)

        resource.should be_dirty
        resource.should_not be_new_record

        @adapter.should_receive(:update).with(resource.dirty_attributes, resource.to_query).and_return(1)

        resource.save.should be_true
      end
    end
  end

  it "should be able to overwrite to_s" do
    Planet.new(:name => 'Mercury').to_s.should == 'Mercury'
  end

  describe "storage names" do
    it "should use its class name by default" do
      Planet.storage_name.should == "planets"
    end

    it "should allow changing using #default_storage_name" do
      Planet.class_eval <<-EOF.margin
        @storage_names.clear
        def self.default_storage_name
          "Superplanet"
        end
      EOF

      Planet.storage_name.should == "superplanets"
      Planet.class_eval <<-EOF.margin
        @storage_names.clear
        def self.default_storage_name
          self.name
        end
      EOF
    end
  end

  it "should require a key" do
    lambda do
      DataMapper::Resource.new("stuff") do
        property :name, String
      end.new
    end.should raise_error(DataMapper::IncompleteResourceError)
  end

  it "should hold repository-specific properties" do
    Planet.properties(:legacy).should have_property(:cowabunga)
    Planet.properties.should_not have_property(:cowabunga)
  end

  it "should track the classes that include it" do
    DataMapper::Resource.descendants.clear
    klass = Class.new { include DataMapper::Resource }
    DataMapper::Resource.descendants.should == Set.new([klass])
  end

  it "should return an instance of the created object" do
    Planet.create!(:name => 'Venus', :age => 1_000_000, :core => nil, :id => 42).should be_a_kind_of(Planet)
  end

  it 'should provide persistance methods' do
    planet = Planet.new
    planet.should respond_to(:new_record?)
    planet.should respond_to(:save)
    planet.should respond_to(:destroy)
  end

  it "should have attributes" do
    attributes = { :name => 'Jupiter', :age => 1_000_000, :core => nil, :id => 42, :type => Planet, :data => nil }
    jupiter = Planet.new(attributes)
    jupiter.attributes.should == attributes
  end

  it "should be able to set attributes" do
    attributes = { :name => 'Jupiter', :age => 1_000_000, :core => nil, :id => 42, :type => Planet, :data => nil }
    jupiter = Planet.new(attributes)
    jupiter.attributes.should == attributes
    jupiter.attributes = attributes.merge(:core => 'Magma')
    jupiter.attributes.should == attributes

    jupiter.update_attributes({ :core => "Toast", :type => "Bob" }, :core).should be_true
    jupiter.core.should == "Toast"
    jupiter.type.should_not == "Bob"
  end

  it "should not mark attributes dirty if there similar after update" do
    jupiter = Planet.new(:name => 'Jupiter', :age => 1_000_000, :core => nil, :id => 42, :data => { :a => "Yeah!" })
    jupiter.save.should be_true

    # discriminator will be set automatically
    jupiter.type.should == Planet

    jupiter.attributes = { :name => 'Jupiter', :age => 1_000_000, :core => nil, :data => { :a => "Yeah!" } }

    jupiter.attribute_dirty?(:name).should be_false
    jupiter.attribute_dirty?(:age).should be_false
    jupiter.attribute_dirty?(:core).should be_false
    jupiter.attribute_dirty?(:data).should be_false

    jupiter.dirty?.should be_false
  end

  it "should not mark attributes dirty if they are similar after typecasting" do
    jupiter = Planet.new(:name => 'Jupiter', :age => 1_000_000, :core => nil, :id => 42, :type => nil)
    jupiter.save.should be_true
    jupiter.dirty?.should be_false

    jupiter.age = '1_000_000'
    jupiter.attribute_dirty?(:age).should be_false
    jupiter.dirty?.should be_false
  end

  it "should track attributes" do

    # So attribute tracking is a feature of the Resource,
    # not the Property. Properties are class-level declarations.
    # Instance-level operations like this happen in Resource with methods
    # and ivars it sets up. Like a @dirty_attributes Array for example to
    # track dirty attributes.

    mars = Planet.new :name => 'Mars'
    # #attribute_loaded? and #attribute_dirty? are a bit verbose,
    # but I like the consistency and grouping of the methods.

    # initialize-set values are dirty as well. DM sets ivars
    # directly when materializing, so an ivar won't exist
    # if the value wasn't loaded by DM initially. Touching that
    # ivar at all will declare it, so at that point it's loaded.
    # This means #attribute_loaded?'s implementation could be very
    # similar (if not identical) to:
    #   def attribute_loaded?(name)
    #     instance_variable_defined?("@#{name}")
    #   end
    mars.attribute_loaded?(:name).should be_true
    mars.attribute_dirty?(:id).should be_false
    mars.attribute_dirty?(:name).should be_true
    mars.attribute_loaded?(:age).should be_false
    mars.attribute_dirty?(:data).should be_false

    mars.age.should be_nil

    # So accessing a value should ensure it's loaded.
    # XXX: why?  if the @ivar isn't set, which it wouldn't be in this
    # case because mars is a new_record?, then perhaps it should return
    # false
    #    mars.attribute_loaded?(:age).should be_true

    # A value should be able to be both loaded and nil.
    mars.age.should be_nil

    # Unless you call #[]= it's not dirty.
    mars.attribute_dirty?(:age).should be_false

    mars.age = 30
    mars.data = { :a => "Yeah!" }

    # Obviously. :-)
    mars.attribute_dirty?(:age).should be_true
    mars.attribute_dirty?(:data).should be_true
  end

  it "should mark the key as dirty, if it is a natural key and has been set" do
    phone = Phone.new
    phone.name = 'iPhone'
    phone.attribute_dirty?(:name).should be_true
  end

  it 'should return the dirty attributes' do
    pluto = Planet.new(:name => 'Pluto', :age => 500_000)
    pluto.attribute_dirty?(:name).should be_true
    pluto.attribute_dirty?(:age).should be_true
  end

  it 'should overwite old dirty attributes with new ones' do
    pluto = Planet.new(:name => 'Pluto', :age => 500_000)
    pluto.dirty_attributes.size.should == 2
    pluto.attribute_dirty?(:name).should be_true
    pluto.attribute_dirty?(:age).should be_true
    pluto.name = "pluto"
    pluto.dirty_attributes.size.should == 2
    pluto.attribute_dirty?(:name).should be_true
    pluto.attribute_dirty?(:age).should be_true
  end

  it 'should provide a key' do
    Planet.new.should respond_to(:key)
  end

  it 'should store and retrieve default values' do
    Planet.property(:satellite_count, Integer, :default => 0)
    # stupid example but it's realiable and works
    Planet.property(:orbit_period, Float, :default => lambda { |r,p| p.name.to_s.length })
    earth = Planet.new(:name => 'Earth')
    earth.satellite_count.should == 0
    earth.orbit_period.should == 12
    earth.satellite_count = 2
    earth.satellite_count.should == 2
    earth.orbit_period = 365.26
    earth.orbit_period.should == 365.26
  end

  describe "anonymity" do
    it "should require a default storage name and accept a block" do
      pluto = DataMapper::Resource.new("planets") do
        property :name, String, :key => true
      end

      pluto.storage_name(:default).should == 'planets'
      pluto.storage_name(:legacy).should == 'planets'
      pluto.properties[:name].should_not be_nil
    end

  end

  describe 'when retrieving by key' do
    it 'should return the corresponding object' do
      m = mock("planet")
      Planet.should_receive(:get).with(1).and_return(m)

      Planet.get!(1).should == m
    end

    it 'should raise an error if not found' do
      Planet.should_receive(:get).and_return(nil)

      lambda do
        Planet.get!(1)
      end.should raise_error(DataMapper::ObjectNotFoundError)
    end
  end

  describe "inheritance" do
    before(:all) do
      class Media
        include DataMapper::Resource

        storage_names[:default] = 'media'
        storage_names[:west_coast] = 'm3d1a'

        property :name, String, :key => true
      end

      class NewsPaper < Media

        storage_names[:east_coast] = 'mother'

        property :rating, Integer
      end
    end

    it 'should inherit storage_names' do
      NewsPaper.storage_name(:default).should == 'media'
      NewsPaper.storage_name(:west_coast).should == 'm3d1a'
      NewsPaper.storage_name(:east_coast).should == 'mother'
      Media.storage_name(:east_coast).should == 'medium'
    end

    it 'should inherit properties' do
      Media.properties.should have(1).entries
      NewsPaper.properties.should have(2).entries
    end
  end

  describe "Single-table Inheritance" do
    before(:all) do
      class Plant
        include DataMapper::Resource

        property :id, Integer, :key => true
        property :length, Integer

        def calculate(int)
          int ** 2
        end

        def length=(len)
          attribute_set(:length, calculate(len))
        end
      end

      class HousePlant < Plant
        def calculate(int)
          int ** 3
        end
      end

      class PoisonIvy < Plant
        def length=(len)
          attribute_set(:length, len - 1)
        end
      end
    end

    it "should be able to overwrite getters" do
      @p = Plant.new
      @p.length = 3
      @p.length.should == 9
    end

    it "should pick overwritten methods" do
      @hp = HousePlant.new
      @hp.length = 3
      @hp.length.should == 27
    end

    it "should pick overwritten setters" do
      @pi = PoisonIvy.new
      @pi.length = 3
      @pi.length.should == 2
    end
  end
end

describe 'DataMapper::Resource::ClassMethods' do
  describe '#transaction' do
    it 'should return a new Transaction with Model as argument' do
      transaction = mock("transaction")
      DataMapper::Transaction.should_receive(:new).with(Planet).and_return(transaction)
      Planet.transaction.should == transaction
    end
  end

  it 'should provide #before' do
    Planet.should respond_to(:before)
  end

  it 'should provide #after' do
    Planet.should respond_to(:after)
  end

  it 'should provide #repository' do
    Planet.should respond_to(:repository)
  end

  describe '#repository' do
    it 'should delegate to DataMapper.repository' do
      repository = mock('repository')
      DataMapper.should_receive(:repository).with(:legacy).and_return(repository)
      Planet.repository(:legacy).should == repository
    end

    it 'should use default repository when not passed any arguments' do
      Planet.repository.name.should == Planet.repository(:default).name
      LegacyStar.repository.name.should == LegacyStar.repository(:legacy).name
    end
  end

  it 'should provide #storage_name' do
    Planet.should respond_to(:storage_name)
  end

  describe '#storage_name' do
    it 'should map a repository to the storage location' do
      Planet.storage_name(:legacy).should == 'dying_planets'
    end

    it 'should use default repository when not passed any arguments' do
      Planet.storage_name.object_id.should == Planet.storage_name(:default).object_id
    end
  end

  it 'should provide #storage_names' do
    Planet.should respond_to(:storage_names)
  end

  describe '#storage_names' do
    it 'should return a Hash mapping each repository to a storage location' do
      Planet.storage_names.should be_kind_of(Hash)
      Planet.storage_names.should == { :default => 'planets', :legacy => 'dying_planets' }
    end
  end

  it 'should provide #property' do
    Planet.should respond_to(:property)
  end

  describe '#property' do
    it 'should raise a SyntaxError when the name contains invalid characters' do
      lambda {
        Planet.property(:"with space", TrueClass)
      }.should raise_error(SyntaxError)
    end
  end

  it 'should provide #properties' do
    Planet.should respond_to(:properties)
  end

  describe '#properties' do
    it 'should return an PropertySet' do
      Planet.properties(:legacy).should be_kind_of(DataMapper::PropertySet)
      Planet.properties(:legacy).should have(7).entries
    end

    it 'should use default repository when not passed any arguments' do
      Planet.properties.object_id.should == Planet.properties(:default).object_id
    end
  end

  it 'should provide #key' do
    Planet.should respond_to(:key)
  end

  describe '#key' do
    it 'should return an Array of Property objects' do
      Planet.key(:legacy).should be_kind_of(Array)
      Planet.key(:legacy).should have(1).entries
      Planet.key(:legacy).first.should be_kind_of(DataMapper::Property)
    end

    it 'should use default repository when not passed any arguments' do
      Planet.key.should == Planet.key(:default)
    end

    it 'should not cache the key value' do
      class GasGiant < Planet
      end

      GasGiant.key.object_id.should_not == Planet.key(:default)

      # change the key and make sure the Array changes
      GasGiant.key == GasGiant.properties.slice(:id)
      GasGiant.property(:new_prop, String, :key => true)
      GasGiant.key.object_id.should_not == Planet.key(:default)
      GasGiant.key == GasGiant.properties.slice(:id, :new_prop)
    end
  end

  it 'should provide #inheritance_property' do
    Planet.should respond_to(:inheritance_property)
  end

  describe '#inheritance_property' do
    it 'should return a Property object' do
      Planet.inheritance_property(:legacy).should be_kind_of(DataMapper::Property)
      Planet.inheritance_property(:legacy).name.should == :type
      Planet.inheritance_property(:legacy).type.should == DataMapper::Types::Discriminator
    end

    it 'should use default repository when not passed any arguments' do
      Planet.inheritance_property.object_id.should == Planet.inheritance_property(:default).object_id
    end
  end

  it 'should provide #get' do
    Planet.should respond_to(:get)
  end

  it 'should provide #first' do
    Planet.should respond_to(:first)
  end

  it 'should provide #all' do
    Planet.should respond_to(:all)
  end

  it 'should provide #storage_exists?' do
    Planet.should respond_to(:storage_exists?)
  end

  describe '#storage_exists?' do
    it 'should return whether or not the storage exists' do
      Planet.should_receive(:repository).with(:default) do
        repository = mock('repository')
        repository.should_receive(:storage_exists?).with('planets').and_return(true)
        repository
      end
      Planet.storage_exists?.should == true
    end
  end

  it 'should provide #default_order' do
    Planet.should respond_to(:default_order)
  end

  describe '#default_order' do
    it 'should be equal to #key by default' do
      Planet.default_order.should == [ DataMapper::Query::Direction.new(Planet.properties[:id], :asc) ]
    end
  end

  describe '#append_inclusions' do
    before(:each) do
      DataMapper::Resource.send(:class_variable_set, '@@extra_inclusions', [])
      DataMapper::Resource::ClassMethods.send(:class_variable_set, '@@extra_extensions', [])

      @module = Module.new do
        def greet
          hi_mom!
        end
      end

      @another_module = Module.new do
        def hello
          hi_dad!
        end
      end

      @class = Class.new

      @class_code = %{
        include DataMapper::Resource
        property :id, Serial
      }
    end

    after(:each) do
      DataMapper::Resource.send(:class_variable_set, '@@extra_inclusions', [])
      DataMapper::Resource::ClassMethods.send(:class_variable_set, '@@extra_extensions', [])
    end

    it "should append the module to be included in resources" do
      DataMapper::Resource.append_inclusions @module
      @class.class_eval(@class_code)

      instance = @class.new
      instance.should_receive(:hi_mom!)
      instance.greet
    end

    it "should append the module to all resources" do
      DataMapper::Resource.append_inclusions @module

      objects = (1..5).map do
        the_class = Class.new
        the_class.class_eval(@class_code)

        instance = the_class.new
        instance.should_receive(:hi_mom!)
        instance
      end

      objects.each { |obj| obj.greet }
    end

    it "should append multiple modules to be included in resources" do
      DataMapper::Resource.append_inclusions @module, @another_module
      @class.class_eval(@class_code)

      instance = @class.new
      instance.should_receive(:hi_mom!)
      instance.should_receive(:hi_dad!)
      instance.greet
      instance.hello
    end

    it "should include the appended modules in order" do
      module_one = Module.new do
        def self.included(base); base.hi_mom!; end;
      end

      module_two = Module.new do
        def self.included(base); base.hi_dad!; end;
      end

      DataMapper::Resource.append_inclusions module_two, module_one

      @class.should_receive(:hi_dad!).once.ordered
      @class.should_receive(:hi_mom!).once.ordered

      @class.class_eval(@class_code)
    end

    it "should append the module to extend resources with" do
      DataMapper::Resource::ClassMethods.append_extensions @module
      @class.class_eval(@class_code)

      @class.should_receive(:hi_mom!)
      @class.greet
    end

    it "should extend all resources with the module" do
      DataMapper::Resource::ClassMethods.append_extensions @module

      classes = (1..5).map do
        the_class = Class.new
        the_class.class_eval(@class_code)
        the_class.should_receive(:hi_mom!)
        the_class
      end

      classes.each { |cla| cla.greet }
    end

    it "should append multiple modules to extend resources with" do
      DataMapper::Resource::ClassMethods.append_extensions @module, @another_module
      @class.class_eval(@class_code)

      @class.should_receive(:hi_mom!)
      @class.should_receive(:hi_dad!)
      @class.greet
      @class.hello
    end

    it "should extend the resource in the order that the modules were appended" do
      @module.class_eval do
        def self.extended(base); base.hi_mom!; end;
      end

      @another_module.class_eval do
        def self.extended(base); base.hi_dad!; end;
      end

      DataMapper::Resource::ClassMethods.append_extensions @another_module, @module

      @class.should_receive(:hi_dad!).once.ordered
      @class.should_receive(:hi_mom!).once.ordered

      @class.class_eval(@class_code)
    end

  end
end
