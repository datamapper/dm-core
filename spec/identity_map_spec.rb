require __DIR__ + 'spec_helper'

describe "DataMapper::IdentityMap" do
  
  it "should"
  
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
      def clear!(type = nil); nil end
      
      # Allows you to remove a specific instance from the cache.
      #
      # +instance+ should respond to the same +resource_class+ and +key+ methods #set does.
      def delete(instance); nil end
    end.new
    
    cache.should respond_to(:get)
    cache.should respond_to(:set)
    cache.should respond_to(:clear!)
    cache.should respond_to(:delete)
    
  end
  
end