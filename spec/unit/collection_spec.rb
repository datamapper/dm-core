require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# ensure the Collection is extremely similar to an Array
# since it will be returned by Respository#all to return
# multiple resources to the caller
describe DataMapper::Collection do

  before :all do
    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]
    DataMapper.setup(:other, "mock://localhost/mock") unless DataMapper::Repository.adapters[:other]

    @cow = Class.new do
      include DataMapper::Resource

      property :name, String, :key => true
      property :age, Fixnum
    end

    properties               = @cow.properties(:default)
    @properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
  end

  before do
    @repository = DataMapper::repository(:default)

    @nancy  = @cow.new(:name => 'Nancy',  :age => 11)
    @bessie = @cow.new(:name => 'Bessie', :age => 10)
    @steve  = @cow.new(:name => 'Steve',  :age => 8)

    @collection = DataMapper::Collection.new(@repository, @cow, @properties_with_indexes)
    @collection.load([ @nancy.name,  @nancy.age  ])
    @collection.load([ @bessie.name, @bessie.age ])

    @other = DataMapper::Collection.new(@repository, @cow, @properties_with_indexes)
    @other.load([ @steve.name, @steve.age ])
  end

  it "should return the right repository" do
    DataMapper::Collection.new(repository(:other), @cow, []).repository.name.should == :other
  end

  it "should be able to add arbitrary objects" do
    properties              = @cow.properties(:default)
    properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]

    collection = DataMapper::Collection.new(DataMapper::repository(:default), @cow, properties_with_indexes)
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

  describe '#&' do
    it 'should alias #& to #intersection' do
      @collection.method(:&).should == @collection.method(:intersection)
    end
  end

  describe '#|' do
    it 'should alias #| to #union' do
      @collection.method(:|).should == @collection.method(:union)
    end
  end

  describe '#+' do
    it 'should alias #+ to #concat' do
      @collection.method(:+).should == @collection.method(:concat)
    end
  end

  describe '#-' do
    it 'should alias #- to #difference' do
      @collection.method(:-).should == @collection.method(:difference)
    end
  end

  describe '#<<' do
    it 'should alias #<< to #push' do
      @collection.method(:<<).should == @collection.method(:push)
    end
  end

  describe '#==' do
    it 'should alias #== to #eql?' do
      @collection.method(:==).should == @collection.method(:eql?)
    end
  end

  describe '#[]' do
    it 'should provide #[]' do
      @collection.should respond_to(:[])
    end

    it 'should alias #[] to #slice' do
      @collection.method(:[]).should == @collection.method(:slice)
    end
  end

  describe '#[]=' do
    it 'should provide #[]=' do
      @collection.should respond_to(:[]=)
    end

    it 'should return the assigned value' do
      (@collection[0] = @steve).should == @steve
    end
  end

  describe '#at' do
    it 'should provide #at' do
      @collection.should respond_to(:at)
    end

    it 'should lookup the resource by index' do
      @collection.at(0).should == @nancy
    end
  end

  describe '#clear' do
    it 'should provide #clear' do
      @collection.should respond_to(:clear)
    end

    it 'should make the collection become empty' do
      @collection.clear.object_id.should == @collection.object_id
      @collection.should be_empty
    end
  end

  describe '#collect!' do
    it 'should provide #collect!' do
      @collection.should respond_to(:collect!)
    end

    it 'should iterate over the collection' do
      collection = []
      @collection.collect! { |resource| collection << resource; resource }
      collection.should == @collection.entries
    end

    it 'should update the collection with the result of the block' do
      @collection.collect! { |resource| @steve }
      @collection.entries.should == [ @steve, @steve ]
    end

    it 'should return self' do
      @collection.collect! { |resource| resource }.object_id.should == @collection.object_id
    end
  end

  describe '#concat' do
    it 'should provide #concat' do
      @collection.should respond_to(:concat)
    end

    it 'should return a Collection' do
      concatenated = @collection.concat(@other)
      concatenated.should be_kind_of(DataMapper::Collection)
      concatenated.object_id.should_not == @collection.object_id
    end

    it 'should concatenate another collection with #concat' do
      concatenated = @collection.concat(@other)
      concatenated.length.should == 3
      concatenated[0].should == @nancy
      concatenated[1].should == @bessie
      concatenated[2].should == @steve
    end
  end

  describe '#difference' do
    it 'should provide #difference' do
      @collection.should respond_to(:difference)
    end

    it 'should return a Collection' do
      difference = @collection.difference(@other)
      difference.should be_kind_of(DataMapper::Collection)
      difference.object_id.should_not == @collection.object_id
    end

    it 'should remove any resources common to both Collections' do
      difference = @collection.difference(@collection)
      difference.object_id.should_not == @collection.object_id
      difference.should be_empty
    end
  end

  describe '#delete' do
    it 'should provide #delete' do
      @collection.should respond_to(:delete)
    end

    it 'should delete the matching resource from the collection' do
      @collection.delete(@nancy).should == @nancy
      @collection.size.should == 1
      @collection[0].should == @bessie
    end

    it 'should use the passed-in block when no resource was removed' do
      @collection.size.should == 2
      @collection.delete(@steve) { @steve }.should == @steve
      @collection.size.should == 2
    end

    it 'should set the resource collection to nil' do
      nancy = @collection.first
      nancy.collection.should == @collection
      @collection.delete(nancy).collection.should be_nil
    end
  end

  describe '#delete_at' do
    it 'should provide #delete_at' do
      @collection.should respond_to(:delete_at)
    end

    it 'should delete the resource from the collection with the index' do
      @collection.delete_at(0).should == @nancy
      @collection.size.should == 1
      @collection[0].should == @bessie
    end

    it 'should set the resource collection to nil' do
      index = 0
      @collection[index].collection.should == @collection
      @collection.delete_at(index).collection.should be_nil
    end
  end

  describe '#delete_if' do
    it 'should alias #delete_if to #reject!' do
      @collection.method(:delete_if).should == @collection.method(:reject!)
    end
  end

  describe '#each' do
    it 'should provide #each' do
      @collection.should respond_to(:each)
    end

    it 'should iterate over the collection' do
      collection = []
      @collection.each { |resource| collection << resource }
      collection.should == @collection.entries
    end

    it 'should return self' do
      @collection.each { |resource| }.object_id.should == @collection.object_id
    end
  end

  describe '#each_index' do
    it 'should provide #each_index' do
      @collection.should respond_to(:each_index)
    end

    it 'should iterate over the collection by index' do
      indexes = []
      @collection.each_index { |index| indexes << index }
      indexes.should == [ 0, 1 ]
    end

    it 'should return self' do
      @collection.each_index { |resource| }.object_id.should == @collection.object_id
    end
  end

  describe '#empty?' do
    it 'should provide #empty?' do
      @collection.should respond_to(:empty?)
    end

    it 'should return true or false if the collection is empty' do
      @collection.length.should == 2
      @collection.empty?.should be_false
      @collection.clear
      @collection.length.should == 0
      @collection.empty?.should be_true
    end
  end

  describe '#eql?' do
    it 'should provide #eql?' do
      @collection.should respond_to(:eql?)
    end

    it 'should test for equality for the same object using #eql?' do
      @collection.object_id.should == @collection.object_id
      @collection.should be_eql(@collection)
    end

    it 'should test for equality for a duplicate object using #eql?' do
      dup = @collection.dup
      dup.object_id.should_not == @collection.object_id
      dup.should be_eql(@collection)
    end
  end

  describe '#fetch' do
    it 'should provide #fetch' do
      @collection.should respond_to(:fetch)
    end

    it 'should lookup the resource with an index' do
      @collection.fetch(0).should == @nancy
    end
  end

  describe '#first' do
    it 'should provide #first' do
      @collection.should respond_to(:first)
    end

    it 'should return the first resource in the collection' do
      @collection.first.should == @nancy
    end

    it 'should return a Collection when number of results specified' do
      collection = @collection.first(2)
      collection.should be_kind_of(DataMapper::Collection)
      collection.length.should == 2
      collection[0].should == @nancy
      collection[1].should == @bessie
    end
  end

  describe '#hash' do
    it 'should provide #hash' do
      @collection.should respond_to(:hash)
    end

    it 'should sum the hashes of its internal state for #hash' do
      loader = nil
      @collection.hash.should == @repository.hash + @cow.hash + @properties_with_indexes.hash + loader.hash + @collection.entries.hash
    end
  end

  describe '#index' do
    it 'should provide #index' do
      @collection.should respond_to(:index)
    end

    it 'should return the first index for the resource in the collection' do
      @collection.index(@nancy).should == 0
    end
  end

  describe '#insert' do
    it 'should provide #insert' do
      @collection.should respond_to(:insert)
    end

    it 'should insert the resource at index in the collection' do
      @collection.insert(1, @steve).object_id.should == @collection.object_id
      @collection[0].should == @nancy
      @collection[1].should == @steve
      @collection[2].should == @bessie
    end
  end

  describe '#intersection' do
    it 'should provide #intersection' do
      @collection.should respond_to(:intersection)
    end

    it 'should return a Collection' do
      intersection = @collection.intersection(@other)
      intersection.should be_kind_of(DataMapper::Collection)
      intersection.object_id.should_not == @collection.object_id
      intersection.object_id.should_not == @other.object_id
    end

    it 'should return an intersection of two Collections' do
      intersection = @collection.intersection(@other)
      intersection.should be_empty

      intersection = @collection.intersection(@collection)
      intersection.length.should == 2
      intersection[0].should == @nancy
      intersection[1].should == @bessie
    end
  end

  describe '#last' do
    it 'should provide #last' do
      @collection.should respond_to(:last)
    end

    it 'should return the last resource in the collection' do
      @collection.last.should == @bessie
    end

    it 'should return a Collection with #last when number of results specified' do
      collection = @collection.last(2)
      collection.should be_kind_of(DataMapper::Collection)
      collection.length.should == 2
    end
  end

  describe '#length' do
    it 'should provide #length' do
      @collection.should respond_to(:length)
    end

    it 'should return the length of the collection' do
      @collection.length.should == 2
    end
  end

  describe '#map!' do
    it 'should alias #map! to #collect!' do
      @collection.method(:map!).should == @collection.method(:collect!)
    end
  end

  describe '#pop' do
    it 'should provide #pop' do
      @collection.should respond_to(:pop)
    end

    it 'should remove the last resource using #pop' do
      @collection.pop.should == @bessie
      @collection.length.should == 1
      @collection[0].should == @nancy
    end

    it 'should set the resource collection to nil' do
      bessie = @collection.last
      bessie.collection.should == @collection
      @collection.pop.collection.should be_nil
    end
  end

  describe '#push' do
    it 'should provide #push' do
      @collection.should respond_to(:push)
    end

    it 'should append a resource using #push' do
      @collection.push(@steve)
      @collection.length.should == 3
      @collection[0].should == @nancy
      @collection[1].should == @bessie
      @collection[2].should == @steve
    end

    it 'should return self' do
      @collection.push(@steve).object_id.should == @collection.object_id
    end
  end

  describe '#reject' do
    it 'should provide #reject' do
      @collection.should respond_to(:reject)
    end

    it 'should return a Collection if no resources matched block' do
      rejected = @collection.reject { |resource| false }
      rejected.should be_kind_of(DataMapper::Collection)
      rejected.object_id.should_not == @collection
      rejected.length.should == 2
      rejected[0].should == @nancy
      rejected[1].should == @bessie
    end

    it 'should return an empty Collection if resources matched block' do
      rejected = @collection.reject { |resource| true }
      rejected.should be_kind_of(DataMapper::Collection)
      rejected.object_id.should_not == @collection
      rejected.length.should == 0
    end
  end

  describe '#reject!' do
    it 'should provide #reject!' do
      @collection.should respond_to(:reject!)
    end

    it 'should remove resources that matched block' do
      @collection.reject! { |resource| true }
      @collection.should be_empty
    end

    it 'should return self if resources matched block' do
      @collection.reject! { |resource| true }.object_id.should == @collection.object_id
    end

    it 'should not remove resources that did not match block' do
      @collection.reject! { |resource| false }
      @collection.length.should == 2
      @collection[0].should == @nancy
      @collection[1].should == @bessie
    end

    it 'should return nil if no resources matched block' do
      @collection.reject! { |resource| false }.should be_nil
    end
  end

  describe '#reverse' do
    it 'should provide #reverse' do
      @collection.should respond_to(:reverse)
    end

    it 'should return a Collection with reversed entries' do
      reversed = @collection.reverse
      reversed.should be_kind_of(DataMapper::Collection)
      reversed.object_id.should_not == @collection
      reversed.entries.should == @collection.entries.reverse
    end
  end

  describe '#reverse!' do
    it 'should provide #reverse!' do
      @collection.should respond_to(:reverse!)
    end

    it 'should reverse the order of resources in the collection inline' do
      entries = @collection.entries
      @collection.reverse!
      @collection.entries.should == entries.reverse
    end

    it 'should return self' do
      @collection.reverse!.object_id.should == @collection.object_id
    end
  end

  describe '#reverse_each' do
    it 'should provide #reverse_each' do
      @collection.should respond_to(:reverse_each)
    end

    it 'should iterate through the collection in reverse' do
      collection = []
      @collection.reverse_each { |resource| collection << resource }
      collection.should == @collection.entries.reverse
    end

    it 'should return self' do
      @collection.reverse_each { |resource| }.object_id.should == @collection.object_id
    end
  end

  describe '#rindex' do
    it 'should provide #rindex' do
      @collection.should respond_to(:rindex)
    end

    it 'should return the last index for the resource in the collection' do
      @collection.rindex(@nancy).should == 0
    end
  end

  describe '#select' do
    it 'should provide #select' do
      @collection.should respond_to(:select)
    end

    it 'should return a Collection with matching resources' do
      selected = @collection.select { |resource| true }
      selected.should be_kind_of(DataMapper::Collection)
      selected.object_id.should_not == @collection
      selected.should == @collection
    end

    it 'should return a Collection with no matching resources' do
      selected = @collection.select { |resource| false }
      selected.should be_kind_of(DataMapper::Collection)
      selected.object_id.should_not == @collection
      selected.should be_empty
    end
  end

  describe '#shift' do
    it 'should provide #shift' do
      @collection.should respond_to(:shift)
    end

    it 'should remove the first resource using #shift' do
      @collection.shift.should == @nancy
      @collection.length.should == 1
      @collection[0].should == @bessie
    end

    it 'should set the resource collection to nil' do
      nancy = @collection.first
      nancy.collection.should == @collection
      @collection.shift.collection.should be_nil
    end

    it 'should alias #size to #length' do
      @collection.method(:size).should == @collection.method(:length)
    end
  end

  describe '#slice' do
    it 'should provide #slice' do
      @collection.should respond_to(:slice)
    end

    it 'should return a Collection with an index' do
      resource = @collection.entries.slice(0)
      resource.should be_kind_of(DataMapper::Resource)
    end

    it 'should return a Collection with a start and length' do
      sliced = @collection.slice(0, 1)
      sliced.should be_kind_of(DataMapper::Collection)
      sliced.object_id.should_not == @collection
      sliced.length.should == 1
      sliced[0].should == @nancy
    end

    it 'should return a Collection with a Range' do
      sliced = @collection.slice(0..1)
      sliced.should be_kind_of(DataMapper::Collection)
      sliced.object_id.should_not == @collection
      sliced.length.should == 2
      sliced[0].should == @nancy
      sliced[1].should == @bessie
    end
  end

  describe '#sort' do
    it 'should provide #sort' do
      @collection.should respond_to(:sort)
    end

    it 'should return a Collection' do
      sorted = @collection.sort { |a,b| a.age <=> b.age }
      sorted.should be_kind_of(DataMapper::Collection)
    end

    it 'should sort the resources' do
      sorted = @collection.sort { |a,b| a.age <=> b.age }
      sorted.object_id.should_not == @collection
      sorted.entries.should == @collection.entries.reverse
    end
  end

  describe '#sort!' do
    it 'should provide #sort!' do
      @collection.should respond_to(:sort!)
    end

    it 'should return self' do
      @collection.sort! { |a,b| 0 }.object_id.should == @collection.object_id
    end

    it 'should sort the Collection in place' do
      original_entries =  @collection.entries.dup
      @collection.length.should == 2
      @collection.sort! { |a,b| a.age <=> b.age }
      @collection.length.should == 2
      @collection.entries.should == original_entries.reverse
    end
  end

  describe '#union' do
    it 'should provide #union' do
      @collection.should respond_to(:union)
    end

    it 'should return a Collection' do
      union = @collection.union(@other)
      union.should be_kind_of(DataMapper::Collection)
      union.object_id.should_not == @collection.object_id
      union.object_id.should_not == @other.object_id
    end

    it 'should return a union of two Collections' do
      union = @collection.union(@other)
      union.length.should == 3
      union[0].should == @nancy
      union[1].should == @bessie
      union[2].should == @steve
    end

    it 'should remove duplicates' do
      other = DataMapper::Collection.new(@repository, @cow, @properties_with_indexes)
      other.load([ @nancy.name, @nancy.age ])
      union = @collection.union(other)
      union.length.should == 2
      union[0].should == @nancy
      union[1].should == @bessie
    end
  end

  describe '#unshift' do
    it 'should provide #unshift' do
      @collection.should respond_to(:unshift)
    end

    it 'should prepend a resource' do
      @collection.unshift(@steve)
      @collection.length.should == 3
      @collection[0].should == @steve
      @collection[1].should == @nancy
      @collection[2].should == @bessie
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

    it 'should return a Collection of the resources at and index' do
      @collection.values_at(0).entries.should == [ @nancy ]
    end
  end

  describe '#reload' do
    it 'should reload lazily initialized fields' do
      @repository.adapter.should_receive(:read_set) do |repository,query|
        repository.should == @repository

        query.should be_instance_of(DataMapper::Query)
        query.reload.should     be_true
        query.offset.should     == 0
        query.limit.should      be_nil
        query.order.should      == []
        query.fields.should     == @cow.properties.slice(:name, :age)
        query.links.should      == []
        query.includes.should   == []
        query.conditions.should == [ [ :eql, @cow.properties[:name], %w[ Nancy Bessie ] ] ]

        []
      end

      @collection.reload.should == []
    end
  end

  describe 'with non-index keys' do
    it 'should instantiate read-only resources' do
      properties_with_indexes = { @cow.properties(:default)[:age] => 0 }

      @collection = DataMapper::Collection.new(@repository, @cow, properties_with_indexes)
      @collection.load([ 1 ])

      @collection.size.should == 1

      resource = @collection.entries[0]

      resource.should be_kind_of(@cow)
      resource.collection.should == @collection
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

  describe 'with lazy loading' do
    before :all do
      DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]

      @cow = Class.new do
        include DataMapper::Resource

        property :name, String, :key => true
        property :age, Fixnum
      end

      properties               = @cow.properties(:default)
      @properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
    end

    it "should make a materialization block" do
      collection = DataMapper::Collection.new(DataMapper::repository(:default), @cow, @properties_with_indexes) do |c|
        c.load(['Bob', 10])
        c.load(['Nancy', 11])
      end

      collection.length.should == 2
    end

    it "should be enumerable" do
      collection = DataMapper::Collection.new(DataMapper::repository(:default), @cow, @properties_with_indexes) do |c|
        c.load(['Bob', 10])
        c.load(['Nancy', 11])
      end

      collection.class.ancestors.should include(Enumerable)

      collection.each do |x|
        x.should be_kind_of(DataMapper::Resource)
      end
    end
  end
end
