require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# ensure the Collection is extremely similar to an Array
# since it will be returned by Respository#all to return
# multiple resources to the caller
describe DataMapper::Collection do
  before :all do

    @cow = Class.new do
      include DataMapper::Resource

      property :name, String, :key => true
      property :age, Fixnum
      has n, :pigs
    end
    
    class Pig
      include DataMapper::Resource
      
      property :name, String, :key => true
      property :age,  Fixnum
      
      belongs_to :cow
    end
    

    properties               = Cow.properties(:default)
    @properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
  end

  before do
    @repository = DataMapper.repository(:default)

    nancy  = Cow.new(:name => 'Nancy',  :age => 11)
    bessie = Cow.new(:name => 'Bessie', :age => 10)
    steve  = Cow.new(:name => 'Steve',  :age => 8)

    babe      = Pig.new(:name => 'Babe')
    snowball  = Pig.new(:name => 'Snowball')
    
    # nancy.pigs << babe << snowball
    

    @collection = DataMapper::Collection.new(@repository, Cow, @properties_with_indexes)
    @collection.load([ nancy.name,  nancy.age  ])
    @collection.load([ bessie.name, bessie.age ])

    @nancy  = @collection[0]
    @bessie = @collection[1]

    @other = DataMapper::Collection.new(@repository, Cow, @properties_with_indexes)
    @other.load([ steve.name, steve.age ])

    @steve = @other[0]
  end

  it "should return the right repository" do
    DataMapper::Collection.new(repository(:legacy), @cow, []).repository.name.should == :legacy
  end

  it "should be able to add arbitrary objects" do
    properties              = Cow.properties(:default)
    properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]

    collection = DataMapper::Collection.new(DataMapper::repository(:default), Cow, properties_with_indexes)
    collection.should respond_to(:reload)

    collection.load(['Bob', 10])
    collection.load(['Nancy', 11])

    results = collection.entries
    results.should have(2).entries

    results.each do |cow|
      cow.instance_variables.should include('@name')
      cow.instance_variables.should include('@age')
    end

    bob, nancy = results[0], results[1]

    bob.name.should eql('Bob')
    bob.age.should eql(10)
    bob.should_not be_a_new_record

    nancy.name.should eql('Nancy')
    nancy.age.should eql(11)
    nancy.should_not be_a_new_record

    results.first.should == bob
  end

  describe '.new' do
    describe 'with non-index keys' do
      it 'should instantiate read-only resources' do
        properties_with_indexes = { Cow.properties(:default)[:age] => 0 }

        @collection = DataMapper::Collection.new(@repository, Cow, properties_with_indexes)
        @collection.load([ 1 ])

        @collection.size.should == 1

        resource = @collection.entries[0]

        resource.should be_kind_of(Cow)
        resource.collection.object_id.should == @collection.object_id
        resource.should_not be_new_record
        resource.should be_readonly
        resource.age.should == 1
      end
    end

    describe 'with inheritance property' do
      before do
        @party = Class.new do
          include DataMapper::Resource

          property :name, String, :key => true
          property :type, Class
        end

        @user = Class.new(@party) do
          include DataMapper::Resource

          property :username, String
          property :password, String
        end

        properties               = @party.properties(:default)
        @properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
      end

      it 'should instantiate resources using the inheritance property class' do
        @collection = DataMapper::Collection.new(@repository, @party, @properties_with_indexes)
        @collection.load([ 'Dan', @user ])
        @collection.length.should == 1
        resource = @collection[0]
        resource.class.should == @user
        resource
      end
    end
  end

  describe '#at' do
    it 'should provide #at' do
      @collection.should respond_to(:at)
    end

    it 'should return a Resource' do
      @collection.at(0).should be_kind_of(DataMapper::Resource)
    end
  end

  describe '#clear' do
    it 'should provide #clear' do
      @collection.should respond_to(:clear)
    end

    it 'should reset the resource.collection' do
      entries = @collection.entries
      entries.each { |r| r.collection.object_id.should == @collection.object_id }
      @collection.clear
      entries.each { |r| r.collection.should be_nil }
    end

    it 'should return self' do
      @collection.clear.object_id.should == @collection.object_id
    end
  end

  describe '#collect!' do
    it 'should provide #collect!' do
      @collection.should respond_to(:collect!)
    end

    it 'should return self' do
      @collection.collect! { |resource| resource }.object_id.should == @collection.object_id
    end
  end

  describe '#concat' do
    it 'should provide #concat' do
      @collection.should respond_to(:concat)
    end

    it 'should return self' do
      @collection.concat(@other).object_id.should == @collection.object_id
    end
  end

  describe '#delete' do
    it 'should provide #delete' do
      @collection.should respond_to(:delete)
    end

    it 'should reset the resource.collection' do
      @nancy.collection.object_id.should == @collection.object_id
      @collection.delete(@nancy)
      @nancy.collection.should be_nil
    end

    it 'should return a Resource' do
      @collection.delete(@nancy).should be_kind_of(DataMapper::Resource)
    end
  end

  describe '#delete_at' do
    it 'should provide #delete_at' do
      @collection.should respond_to(:delete_at)
    end

    it 'should reset the resource.collection' do
      @nancy.collection.object_id.should == @collection.object_id
      @collection.delete_at(0)
      @nancy.collection.should be_nil
    end

    it 'should return a Resource' do
      @collection.delete_at(0).should be_kind_of(DataMapper::Resource)
    end
  end

  describe '#each' do
    it 'should provide #each' do
      @collection.should respond_to(:each)
    end

    it 'should return self' do
      @collection.each { |resource| }.object_id.should == @collection.object_id
    end
  end

  describe '#each_index' do
    it 'should provide #each_index' do
      @collection.should respond_to(:each_index)
    end

    it 'should return self' do
      @collection.each_index { |resource| }.object_id.should == @collection.object_id
    end
  end

  describe '#eql?' do
    it 'should provide #eql?' do
      @collection.should respond_to(:eql?)
    end

    it 'should return true if for the same collection' do
      @collection.object_id.should == @collection.object_id
      @collection.should be_eql(@collection)
    end

    it 'should return true for duplicate collections' do
      dup = @collection.dup
      dup.should be_kind_of(DataMapper::Collection)
      dup.object_id.should_not == @collection.object_id
      dup.entries.should == @collection.entries
      dup.should be_eql(@collection)
    end

    it 'should return false for different collections' do
      @collection.should_not be_eql(@other)
    end
  end

  describe '#fetch' do
    it 'should provide #fetch' do
      @collection.should respond_to(:fetch)
    end

    it 'should return a Resource' do
      @collection.fetch(0).should be_kind_of(DataMapper::Resource)
    end
  end

  describe '#first' do
    it 'should provide #first' do
      @collection.should respond_to(:first)
    end

    describe 'with no arguments' do
      it 'should return a Resource' do
        @collection.first.should be_kind_of(DataMapper::Resource)
      end
    end

    describe 'with number of results specified' do
      it 'should return a Collection ' do
        collection = @collection.first(2)
        collection.should be_kind_of(DataMapper::Collection)
        collection.object_id.should_not == @collection.object_id
        collection.length.should == 2
        collection[0].should == @nancy
        collection[1].should == @bessie
      end
    end    
  end

  describe '#insert' do
    it 'should provide #insert' do
      @collection.should respond_to(:insert)
    end

    it 'should return self' do
      @collection.insert(1, @steve).object_id.should == @collection.object_id
    end
  end

  describe '#last' do
    it 'should provide #last' do
      @collection.should respond_to(:last)
    end

    describe 'with no arguments' do
      it 'should return a Resource' do
        @collection.last.should be_kind_of(DataMapper::Resource)
      end
    end

    describe 'with number of results specified' do
      it 'should return a Collection ' do
        collection = @collection.last(2)
        collection.should be_kind_of(DataMapper::Collection)
        collection.object_id.should_not == @collection.object_id
        collection.length.should == 2
        collection[0].should == @nancy
        collection[1].should == @bessie
      end
    end
  end

  describe '#load' do
    it 'should load resources from the identity map when possible' do
      @steve.collection = nil
      @repository.should_receive(:identity_map_get).with(Cow, %w[ Steve ]).once.and_return(@steve)
      collection = DataMapper::Collection.new(@repository, Cow, @properties_with_indexes)
      collection.load([ @steve.name, @steve.age ])
      collection.size.should == 1
      collection[0].object_id.should == @steve.object_id
      @steve.collection.object_id.should == collection.object_id
    end
  end

  describe '#loaded?' do
    it 'should provide #loaded?' do
      @collection.should respond_to(:loaded?)
    end

    it 'should return true for an initialized collection' do
      @collection.should be_loaded
    end

    it 'should return false for an uninitialized collection' do
      uninitialized = DataMapper::Collection.new(@repository, Cow, @properties_with_indexes) do
        # do nothing
      end
      uninitialized.should_not be_loaded
    end
  end

  describe '#pop' do
    it 'should provide #pop' do
      @collection.should respond_to(:pop)
    end

    it 'should reset the resource.collection' do
      @bessie.collection.object_id.should == @collection.object_id
      @collection.pop
      @bessie.collection.should be_nil
    end

    it 'should return a Resource' do
      @collection.pop.should be_kind_of(DataMapper::Resource)
    end
  end

  describe '#push' do
    it 'should provide #push' do
      @collection.should respond_to(:push)
    end

    it 'should return self' do
      @collection.push(@steve).object_id.should == @collection.object_id
    end
  end

  describe '#reject' do
    it 'should provide #reject' do
      @collection.should respond_to(:reject)
    end

    it 'should return a Collection with resources that did not match the block' do
      rejected = @collection.reject { |resource| false }
      rejected.should be_kind_of(DataMapper::Collection)
      rejected.object_id.should_not == @collection.object_id
      rejected.length.should == 2
      rejected[0].should == @nancy
      rejected[1].should == @bessie
    end

    it 'should return an empty Collection if resources matched the block' do
      rejected = @collection.reject { |resource| true }
      rejected.should be_kind_of(DataMapper::Collection)
      rejected.object_id.should_not == @collection.object_id
      rejected.length.should == 0
    end
  end

  describe '#reject!' do
    it 'should provide #reject!' do
      @collection.should respond_to(:reject!)
    end

    it 'should return self if resources matched the block' do
      @collection.reject! { |resource| true }.object_id.should == @collection.object_id
    end

    it 'should return nil if no resources matched the block' do
      @collection.reject! { |resource| false }.should be_nil
    end
  end

  describe '#reload' do
    it 'should return self' do
      @repository.adapter.should_receive(:read_set).once.and_return(@collection)
      @collection.reload.object_id.should == @collection.object_id
    end

    it 'should replace the collection with the results of read_set' do
      @repository.adapter.should_receive(:read_set).once.and_return(@other)
      @collection.object_id.should_not == @other.object_id
      @collection.size.should == 2
      @collection.reload.should == @other
      @collection.size.should == 1
    end

    it 'should reload lazily initialized fields' do
      @repository.adapter.should_receive(:read_set) do |repository,query|
        repository.should == @repository

        query.should be_instance_of(DataMapper::Query)
        query.reload.should     be_true
        query.offset.should     == 0
        query.limit.should      be_nil
        query.order.should      == []
        query.fields.should     == Cow.properties.slice(:name, :age)
        query.links.should      == []
        query.includes.should   == []
        query.conditions.should == [ [ :eql, Cow.properties[:name], %w[ Nancy Bessie ] ] ]

        @collection
      end

      @collection.reload
    end
  end

  describe '#reverse' do
    it 'should provide #reverse' do
      @collection.should respond_to(:reverse)
    end

    it 'should return a Collection with reversed entries' do
      reversed = @collection.reverse
      reversed.should be_kind_of(DataMapper::Collection)
      reversed.object_id.should_not == @collection.object_id
      reversed.entries.should == @collection.entries.reverse
    end
  end

  describe '#reverse!' do
    it 'should provide #reverse!' do
      @collection.should respond_to(:reverse!)
    end

    it 'should return self' do
      @collection.reverse!.object_id.should == @collection.object_id
    end
  end

  describe '#reverse_each' do
    it 'should provide #reverse_each' do
      @collection.should respond_to(:reverse_each)
    end

    it 'should return self' do
      @collection.reverse_each { |resource| }.object_id.should == @collection.object_id
    end
  end

  describe '#select' do
    it 'should provide #select' do
      @collection.should respond_to(:select)
    end

    it 'should return a Collection with resources that matched the block' do
      selected = @collection.select { |resource| true }
      selected.should be_kind_of(DataMapper::Collection)
      selected.object_id.should_not == @collection.object_id
      selected.should == @collection
    end

    it 'should return an empty Collection if no resources matched the block' do
      selected = @collection.select { |resource| false }
      selected.should be_kind_of(DataMapper::Collection)
      selected.object_id.should_not == @collection.object_id
      selected.should be_empty
    end
  end

  describe '#shift' do
    it 'should provide #shift' do
      @collection.should respond_to(:shift)
    end

    it 'should reset the resource.collection' do
      @nancy.collection.object_id.should == @collection.object_id
      @collection.shift
      @nancy.collection.should be_nil
    end

    it 'should return a Resource' do
      @collection.shift.should be_kind_of(DataMapper::Resource)
    end
  end

  describe '#slice' do
    it 'should provide #slice' do
      @collection.should respond_to(:slice)
    end

    describe 'with an index' do
      it 'should return a Resource' do
        resource = @collection.slice(0)
        resource.should be_kind_of(DataMapper::Resource)
      end
    end

    describe 'with a start and length' do
      it 'should return a Collection' do
        sliced = @collection.slice(0, 1)
        sliced.should be_kind_of(DataMapper::Collection)
        sliced.object_id.should_not == @collection.object_id
        sliced.length.should == 1
        sliced[0].should == @nancy
      end
    end

    describe 'with a Range' do
      it 'should return a Collection' do
        sliced = @collection.slice(0..1)
        sliced.should be_kind_of(DataMapper::Collection)
        sliced.object_id.should_not == @collection.object_id
        sliced.length.should == 2
        sliced[0].should == @nancy
        sliced[1].should == @bessie
      end
    end
  end

  describe '#slice!' do
    it 'should provide #slice!' do
      @collection.should respond_to(:slice!)
    end

    describe 'with an index' do
      it 'should return a Resource' do
        resource = @collection.slice!(0)
        resource.should be_kind_of(DataMapper::Resource)
      end
    end

    describe 'with a start and length' do
      it 'should return a Collection' do
        sliced = @collection.slice!(0, 1)
        sliced.should be_kind_of(DataMapper::Collection)
        sliced.object_id.should_not == @collection.object_id
        sliced.length.should == 1
        sliced[0].should == @nancy
      end
    end

    describe 'with a Range' do
      it 'should return a Collection' do
        sliced = @collection.slice(0..1)
        sliced.should be_kind_of(DataMapper::Collection)
        sliced.object_id.should_not == @collection.object_id
        sliced.length.should == 2
        sliced[0].should == @nancy
        sliced[1].should == @bessie
      end
    end
  end

  describe '#sort' do
    it 'should provide #sort' do
      @collection.should respond_to(:sort)
    end

    it 'should return a Collection' do
      sorted = @collection.sort { |a,b| a.age <=> b.age }
      sorted.should be_kind_of(DataMapper::Collection)
      sorted.object_id.should_not == @collection.object_id
    end
  end

  describe '#sort!' do
    it 'should provide #sort!' do
      @collection.should respond_to(:sort!)
    end

    it 'should return self' do
      @collection.sort! { |a,b| 0 }.object_id.should == @collection.object_id
    end
  end

  describe '#unshift' do
    it 'should provide #unshift' do
      @collection.should respond_to(:unshift)
    end

    it 'should return self' do
      @collection.unshift(@steve).object_id.should == @collection.object_id
    end
  end

  describe '#values_at' do
    it 'should provide #values_at' do
      @collection.should respond_to(:values_at)
    end

    it 'should return a Collection' do
      values = @collection.values_at(0)
      values.should be_kind_of(DataMapper::Collection)
      values.object_id.should_not == @collection.object_id
    end

    it 'should return a Collection of the resources at the index' do
      @collection.values_at(0).entries.should == [ @nancy ]
    end
  end

  describe 'with lazy loading' do
    before :all do
      @cow = Class.new do
        include DataMapper::Resource

        property :name, String, :key => true
        property :age, Fixnum
      end

      properties               = Cow.properties(:default)
      @properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
    end

    it "should make a materialization block" do
      collection = DataMapper::Collection.new(DataMapper::repository(:default), Cow, @properties_with_indexes) do |c|
        c.should be_empty
        c.load(['Bob', 10])
        c.load(['Nancy', 11])
      end

      collection.length.should == 2
    end
  end
  
end
