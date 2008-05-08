require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# rSpec completely FUBARs everything if you give it a Module here.
# So we give it a String of the module name instead.
# DO NOT CHANGE THIS!
describe "DataMapper::Resource" do

  before :all do

    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]
    DataMapper.setup(:legacy, "mock://localhost/mock") unless DataMapper::Repository.adapters[:legacy]

    unless DataMapper::Repository.adapters[:yet_another_repository]
      adapter = DataMapper.setup(:yet_another_repository, "mock://localhost/mock")
      adapter.resource_naming_convention = DataMapper::NamingConventions::Underscored
    end

    class Planet

      include DataMapper::Resource

      storage_names[:legacy] = "dying_planets"

      property :id, Fixnum, :key => true
      property :name, String, :lock => true
      property :age, Fixnum
      property :core, String, :private => true
      property :type, Class

      repository(:legacy) do
        property :cowabunga, String
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
      property :awesomeness, Fixnum
    end
  end
  
  it "should hold repository-specific properties" do
    Planet.properties(:legacy).should have_property(:cowabunga)
    Planet.properties.should_not have_property(:cowabunga)
  end

  it "should track the classes that include it" do
    DataMapper::Resource.including_classes.clear
    Moon.class_eval do include(DataMapper::Resource) end
    DataMapper::Resource.including_classes.should == Set.new([Moon])
  end

  it "should return an instance of the created object" do
    Planet.create(:name => 'Venus', :age => 1_000_000, :core => nil, :id => 42).should be_a_kind_of(Planet)
  end

  it 'should provide persistance methods' do
    planet = Planet.new
    planet.should respond_to(:new_record?)
    planet.should respond_to(:save)
    planet.should respond_to(:destroy)
  end

  it "should have attributes" do
    attributes = { :name => 'Jupiter', :age => 1_000_000, :core => nil, :id => 42, :type => nil }
    jupiter = Planet.new(attributes)
    jupiter.attributes.should == attributes
  end

  it "should be able to set attributes (including private attributes)" do
    attributes = { :name => 'Jupiter', :age => 1_000_000, :core => nil, :id => 42, :type => nil }
    jupiter = Planet.new(attributes)
    jupiter.attributes.should == attributes
    jupiter.attributes = attributes.merge({ :core => 'Magma' })
    jupiter.attributes.should == attributes
    jupiter.send(:private_attributes=, attributes.merge({ :core => 'Magma' }))
    jupiter.attributes.should == attributes.merge({ :core => 'Magma' })
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

    mars.age.should be_nil

    # So accessing a value should ensure it's loaded.
    # XXX: why?  if the @ivar isn't set, which it wouldn't be in this
    # case because mars is a new_record?, then perhaps it should return
    # false
    #    mars.attribute_loaded?(:age).should be_true

    # A value should be able to be both loaded and nil.
    mars.attribute_get(:age).should be_nil

    # Unless you call #[]= it's not dirty.
    mars.attribute_dirty?(:age).should be_false

    mars.attribute_set(:age, 30)
    # Obviously. :-)
    mars.attribute_dirty?(:age).should be_true

    mars.should respond_to(:shadow_attribute_get)
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

  it 'should temporarily store original values for locked attributes' do
    mars = Planet.new
    mars.instance_variable_set('@name', 'Mars')
    mars.instance_variable_set('@new_record', false)

    mars.attribute_set(:name, 'God of War')
    mars.attribute_get(:name).should == 'God of War'
    mars.name.should == 'God of War'
    mars.shadow_attribute_get(:name).should == 'Mars'
  end

  it 'should store and retrieve default values' do
    Planet.property(:satellite_count, Fixnum, :default => 0)
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
  describe 'ClassMethods' do

    it "should return a new Transaction with itself as argument on #transaction" do
      transaction = mock("transaction")
      DataMapper::Transaction.should_receive(:new).once.with(Planet).and_return(transaction)
      Planet.transaction.should == transaction
    end

    it 'should add hook functionality to including class' do
      Planet.should respond_to(:before)
      Planet.should respond_to(:after)
    end

    it 'should provide a repository' do
      Planet.should respond_to(:repository)
    end

    it '.repository should delegate to DataMapper.repository' do
      repository = mock('repository')
      DataMapper.should_receive(:repository).with(:legacy).once.and_return(repository)
      Planet.repository(:legacy).should == repository
    end

    it '.repository should use default repository when not passed any arguments' do
      Planet.repository.name.should == Planet.repository(:default).name
      LegacyStar.repository.name.should == LegacyStar.repository(:legacy).name
    end

    it 'should provide storage_name' do
      Planet.should respond_to(:storage_name)
    end

    it '.storage_name should map a repository to the storage location' do
      Planet.storage_name(:legacy).should == 'dying_planets'
    end

    it '.storage_name should use default repository when not passed any arguments' do
      Planet.storage_name.object_id.should == Planet.storage_name(:default).object_id
    end

    it 'should provide storage_names' do
      Planet.should respond_to(:storage_names)
    end

    it '.storage_names should return a Hash mapping each repository to a storage location' do
      Planet.storage_names.should be_kind_of(Hash)
      Planet.storage_names.should == { :default => 'planets', :legacy => 'dying_planets' }
    end

    it 'should provide property' do
      Planet.should respond_to(:property)
    end

    it 'should specify property'

    it 'should provide properties' do
      Planet.should respond_to(:properties)
    end

    it '.properties should return an PropertySet' do
      Planet.properties(:legacy).should be_kind_of(DataMapper::PropertySet)
      Planet.properties(:legacy).should have(6).entries
    end

    it '.properties should use default repository when not passed any arguments' do
      Planet.properties.object_id.should == Planet.properties(:default).object_id
    end

    it 'should provide key' do
      Planet.should respond_to(:key)
    end

    it '.key should return an Array of Property objects' do
      Planet.key(:legacy).should be_kind_of(Array)
      Planet.key(:legacy).should have(1).entries
      Planet.key(:legacy).first.should be_kind_of(DataMapper::Property)
    end

    it '.key should use default repository when not passed any arguments' do
      Planet.key.object_id.should == Planet.key(:default).object_id
    end

    it 'should provide inheritance_property' do
      Planet.should respond_to(:inheritance_property)
    end

    it '.inheritance_property should return a Property object' do
      Planet.inheritance_property(:legacy).should be_kind_of(DataMapper::Property)
      Planet.inheritance_property(:legacy).name.should == :type
      Planet.inheritance_property(:legacy).type.should == Class
    end

    it '.inheritance_property should use default repository when not passed any arguments' do
      Planet.inheritance_property.object_id.should == Planet.inheritance_property(:default).object_id
    end

    it 'should provide finder methods' do
      Planet.should respond_to(:get)
      Planet.should respond_to(:first)
      Planet.should respond_to(:all)
      Planet.should respond_to(:[])
    end
    
    it '.exists? should return whether or not the repository exists' do
      Planet.should respond_to(:exists?)
      Planet.exists?.should == true
    end
    
  end
  
  describe "anonymity" do
    
    before(:all) do
      DataMapper.setup(:andromeda, 'mock://localhost')
    end
    
    it "should require a default storage name and accept a block" do
      pluto = DataMapper::Resource.new("planet") do
        property :name, String, :key => true
      end
      
      pluto.storage_name(:default).should == 'planets'
      pluto.storage_name(:andromeda).should == 'planets'
      pluto.properties[:name].should_not be_nil
    end
    
  end

  describe 'when retrieving by key' do
    it 'should return the corresponding object' do
      m = mock("planet")
      Planet.should_receive(:get).with(1).and_return(m)

      Planet[1].should == m
    end

    it 'should raise an error if not found' do
      Planet.should_receive(:get).and_return(nil)

      lambda do
        Planet[1]
      end.should raise_error(DataMapper::ObjectNotFoundError)
    end
  end
  
  describe "inheritance" do
    before(:all) do
      
      DataMapper.setup(:west_coast, "mock://localhost/mock") unless DataMapper::Repository.adapters[:west_coast]
      DataMapper.setup(:east_coast, "mock://localhost/mock") unless DataMapper::Repository.adapters[:east_coast]
      
      class Media
        include DataMapper::Resource
        
        storage_names[:default] = 'media'
        storage_names[:west_coast] = 'm3d1a'
        
        property :name, String, :key => true
      end
      
      class NewsPaper < Media
        
        storage_names[:east_coast] = 'mother'
        
        property :rating, Fixnum
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
  
end
