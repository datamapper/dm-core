require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe "DataMapper::IdentityMap" do
  before(:all) do
    class Cow
      include DataMapper::Resource
      property :id, Fixnum, :key => true
      property :name, String
    end

    class Chicken
      include DataMapper::Resource
      property :name, String
    end

    class Pig
      include DataMapper::Resource
      property :id, Fixnum, :key => true
      property :composite, Fixnum, :key => true
      property :name, String
    end
  end

  it "should use a second level cache if created with on"

  it "should return nil on #get when it does not find the requested instance" do
    map = DataMapper::IdentityMap.new
    map.get(Cow,[23]).nil?.should == true
  end

  it "should return an instance on #get when it finds the requested instance" do
    betsy = Cow.new({:id=>23,:name=>'Betsy'})
    map = DataMapper::IdentityMap.new
    map.set(betsy)
    map.get(Cow,[23]).should == betsy
  end

  it "should store an instance on #set" do
    betsy = Cow.new({:id=>23,:name=>'Betsy'})
    map = DataMapper::IdentityMap.new
    map.set(betsy)
    map.get(Cow,[23]).should == betsy
  end

  it "should raise ArgumentError on #set if there is no key property" do
    cluck = Chicken.new({:name => 'Cluck'})
    map = DataMapper::IdentityMap.new
    lambda{map.set(cluck)}.should raise_error(ArgumentError)
  end

  it "should raise ArgumentError on #set if the key property is nil" do
    betsy = Cow.new({:name=>'Betsy'})
    map = DataMapper::IdentityMap.new
    lambda{ map.set(betsy)}.should raise_error(ArgumentError)
  end

  it "should store instances with composite keys on #set" do
    pig = Pig.new({:id=>1,:composite=>1,:name=> 'Pig'})
    piggy = Pig.new({:id=>1,:composite=>2,:name=>'Piggy'})

    map = DataMapper::IdentityMap.new
    map.set(pig)
    map.set(piggy)

    map.get(Pig,[1,1]).should == pig
    map.get(Pig,[1,2]).should == piggy
  end

  it "should remove an instance on #delete" do
    betsy = Cow.new({:id=>23,:name=>'Betsy'})
    map = DataMapper::IdentityMap.new
    map.set(betsy)
    map.delete(Cow,[23])
    map.get(Cow,[23]).nil?.should == true
  end

  it "should remove all instances of a given class on #clear" do
    betsy = Cow.new({:id=>23,:name=>'Betsy'})
    bert = Cow.new({:id=>24,:name=>'Bert'})
    piggy = Pig.new({:id=>1,:composite=>2,:name=>'Piggy'})

    map = DataMapper::IdentityMap.new
    map.set(betsy)
    map.set(bert)
    map.set(piggy)
    map.clear(Cow)
    map.get(Cow,[23]).nil?.should == true
    map.get(Cow,[24]).nil?.should == true
    map.get(Pig,[1,2]).should == piggy
  end



end

describe "Second Level Caching" do

  it "should expose a standard API" do

    cache = Class.new do

      # Retrieve an instance by it's type and key.
      #
      # +klass+ is the type you want to retrieve. Should
      # map to a mapped class. ie: If you have Salesperson < Person, then
      # you should be able to pass in Salesperson, but it should map the
      # lookup to it's set os Person instances.
      #
      # +type+ is an order-specific Array of key-values to identify the object.
      # It's always an Array, even when not using a composite-key. ie:
      #   property :id, Fixnum, :serial => true # => [12]
      # Or:
      #   property :order_id, Fixnum
      #   property :line_item_number, Fixnum
      #   # key => [5, 27]
      #
      # +return+ nil when a matching instance isn't found,
      # or the matching instance when present.
      def get(type, key); nil end

      # Store an instance in the map.
      #
      # +instance+ is the instance you want to store. The cache should
      # identify the type-store by instance.class in a naive implementation,
      # or if inheritance is allowed, instance.resource_class (not yet implemented).
      # The instance must also respond to #key, to return it's key. If key returns nil
      # or an empty Array, then #set should raise an error.
      def set(instance); instance end

      # Clear should flush the entire cache.
      #
      # +type+ if an optional type argument is passed, then
      # only the storage for that type should be cleared.
      def clear(type = nil); nil end

      # Allows you to remove a specific instance from the cache.
      #
      # +instance+ should respond to the same +resource_class+ and +key+ methods #set does.
      def delete(instance); nil end
    end.new

    cache.should respond_to(:get)
    cache.should respond_to(:set)
    cache.should respond_to(:clear)
    cache.should respond_to(:delete)

  end

end
