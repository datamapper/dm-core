require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  class Zebra
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :id, Integer, :serial => true
    property :name, String
    property :age, Integer
    property :notes, Text

    has n, :stripes
  end

  class Stripe
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :id, Integer, :serial => true
    property :name, String
    property :age,  Integer
    property :zebra_id, Integer

    belongs_to :zebra
  end

  module CollectionSpecHelper
    def setup
      Zebra.auto_migrate!(ADAPTER)
      Stripe.auto_migrate!(ADAPTER)

      repository(ADAPTER) do
        @nancy  = Zebra.create(:name => 'Nancy',  :age => 11, :notes => 'Spotted!')
        @bessie = Zebra.create(:name => 'Bessie', :age => 10, :notes => 'Striped!')
        @steve  = Zebra.create(:name => 'Steve',  :age => 8,  :notes => 'Bald!')

        @babe     = Stripe.create(:name => 'Babe')
        @snowball = Stripe.create(:name => 'snowball')

        @nancy.stripes = [ @babe, @snowball ]
      end
    end
  end

  describe 'association proxying' do
    include CollectionSpecHelper

    before :all do
      setup
    end

    it "should provide a Query" do
      repository(ADAPTER) do
        zebras = Zebra.all(:order => [ :name ])
        zebras.query.order.should == [DataMapper::Query::Direction.new(Zebra.properties(ADAPTER)[:name])]
      end
    end

    it "should proxy the relationships of the model" do
      repository(ADAPTER) do
        zebras = Zebra.all
        zebras.should have(3).entries
        zebras.find { |zebra| zebra.name == 'Nancy' }.stripes.should have(2).entries
        zebras.stripes.should == [@babe, @snowball]
      end
    end

    it "should preserve it's order on reload" do
      repository(ADAPTER) do |r|
        zebras = Zebra.all(:order => [ :name ])

        order = %w{ Bessie Nancy Steve }

        zebras.map { |z| z.name }.should == order

        # Force a lazy-load call:
        zebras.first.notes

        # The order should be unaffected.
        zebras.map { |z| z.name }.should == order
      end
    end
  end

  describe DataMapper::Collection do
    include CollectionSpecHelper

    before :all do
      setup
    end

    before do
      @repository = repository(ADAPTER)
      @model      = Zebra
      @query      = DataMapper::Query.new(@repository, @model, :order => [ :id ])
      @collection = @repository.all(@model, @query)
      @other      = @repository.all(@model, @query.merge(:limit => 2))
    end

    it "should return the right repository" do
      DataMapper::Collection.new(DataMapper::Query.new(repository(:legacy), @model)).repository.name.should == :legacy
    end

    it "should be able to add arbitrary objects" do
      properties = @model.properties(:default)

      collection = DataMapper::Collection.new(@query)
      collection.should respond_to(:reload)

      collection.load([ 4, 'Bob',   10 ])
      collection.load([ 5, 'Nancy', 11 ])

      results = collection.entries
      results.should have(2).entries

      results.each do |cow|
        cow.attribute_loaded?(:name).should be_true
        cow.attribute_loaded?(:age).should be_true
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
          @collection = DataMapper::Collection.new(DataMapper::Query.new(@repository, @model, :fields => [ :age ]))
          @collection.load([ 1 ])

          @collection.size.should == 1

          resource = @collection.entries[0]

          resource.should be_kind_of(@model)
          resource.collection.object_id.should == @collection.object_id
          resource.should_not be_new_record
          resource.should be_readonly
          resource.age.should == 1
        end
      end

      describe 'with inheritance property' do
        before do
          class CollectionSpecParty
            include DataMapper::Resource
            property :name, String, :key => true
            property :type, Discriminator
          end

          class CollectionSpecUser < CollectionSpecParty
            property :username, String
            property :password, String
          end

          properties = CollectionSpecParty.properties(:default)
        end

        it 'should instantiate resources using the inheritance property class' do
          @collection = DataMapper::Collection.new(DataMapper::Query.new(@repository, CollectionSpecParty))
          @collection.load([ 'Dan', CollectionSpecUser ])
          @collection.length.should == 1
          resource = @collection[0]
          resource.class.should == CollectionSpecUser
          resource
        end
      end
    end

    [ true, false ].each do |loaded|
      describe " (#{loaded ? 'loaded' : 'not loaded'}) " do
        before do
          @collection.to_a if loaded
        end

        describe '#all' do
          describe 'with no arguments' do
            it 'should return self' do
              @collection.all.object_id.should == @collection.object_id
            end
          end

          describe 'with query arguments' do
            describe 'should return a Collection' do
              before do
                @query.update(:offset => 10, :limit => 10)
                query = DataMapper::Query.new(@repository, @model)
                @unlimited = DataMapper::Collection.new(query)
              end

              it 'has an offset equal to 10' do
                @collection.all.query.offset.should == 10
              end

              it 'has a cumulative offset equal to 11 when passed an offset of 1' do
                @collection.all(:offset => 1).query.offset.should == 11
              end

              it 'has a cumulative offset equal to 19 when passed an offset of 9' do
                @collection.all(:offset => 9).query.offset.should == 19
              end

              it 'is empty when passed an offset that is out of range' do
                pending do
                  empty_collection = @collection.all(:offset => 10)
                  empty_collection.should be_empty
                  empty_collection.should be_loaded
                end
              end

              it 'has an limit equal to 10' do
                @collection.all.query.limit.should == 10
              end

              it 'has a limit equal to 5' do
                @collection.all(:limit => 5).query.limit.should == 5
              end

              it 'has a limit equal to 10 if passed a limit greater than 10' do
                @collection.all(:limit => 11).query.limit.should == 10
              end

              it 'has no limit' do
                @unlimited.all.query.limit.should be_nil
              end

              it 'has a limit equal to 1000 when passed a limit of 1000' do
                @unlimited.all(:limit => 1000).query.limit.should == 1000
              end
            end
          end
        end

        describe '#at' do
          it 'should return a Resource' do
            resource_at = @collection.at(1)
            resource_at.should be_kind_of(DataMapper::Resource)
            resource_at.id.should == @bessie.id
          end
        end

        describe '#clear' do
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
          it 'should return self' do
            @collection.collect! { |resource| resource }.object_id.should == @collection.object_id
          end
        end

        describe '#concat' do
          it 'should return self' do
            @collection.concat(@other).object_id.should == @collection.object_id
          end
        end

        describe '#delete' do
          it 'should reset the resource.collection' do
            @nancy = @collection[0]

            @nancy.collection.object_id.should == @collection.object_id
            @collection.delete(@nancy)
            @nancy.collection.should be_nil
          end

          it 'should return a Resource' do
            @collection.delete(@nancy).should be_kind_of(DataMapper::Resource)
          end
        end

        describe '#delete_at' do
          it 'should reset the resource.collection' do
            @nancy = @collection[0]

            @nancy.collection.object_id.should == @collection.object_id
            @collection.delete_at(0)
            @nancy.collection.should be_nil
          end

          it 'should return a Resource' do
            @collection.delete_at(0).should be_kind_of(DataMapper::Resource)
          end
        end

        describe '#each' do
          it 'should return self' do
            @collection.each { |resource| }.object_id.should == @collection.object_id
          end
        end

        describe '#each_index' do
          it 'should return self' do
            @collection.each_index { |resource| }.object_id.should == @collection.object_id
          end
        end

        describe '#eql?' do
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
          it 'should return a Resource' do
            @collection.fetch(0).should be_kind_of(DataMapper::Resource)
          end
        end

        describe '#first' do
          describe 'with no arguments' do
            it 'should return a Resource' do
              first = @collection.first
              first.should_not be_nil
              first.should be_kind_of(DataMapper::Resource)
              first.id.should == @nancy.id
            end
          end

          describe 'with limit specified' do
            it 'should return a Collection' do
              collection = @collection.first(2)

              collection.should be_kind_of(DataMapper::Collection)
              collection.object_id.should_not == @collection.object_id

              collection.query.order.size.should == 1
              collection.query.order.first.property.should == @model.properties[:id]
              collection.query.order.first.direction.should == :asc

              collection.query.offset.should == 0
              collection.query.limit.should == 2

              collection.length.should == 2

              collection.entries.map { |r| r.id }.should == [ @nancy.id, @bessie.id ]
            end

            it 'should return a Collection if limit is 1' do
              collection = @collection.first(1)

              collection.should be_kind_of(DataMapper::Collection)
              collection.object_id.should_not == @collection.object_id
            end
          end
        end

        describe '#insert' do
          it 'should return self' do
            @collection.insert(1, @steve).object_id.should == @collection.object_id
          end
        end

        describe '#last' do
          describe 'with no arguments' do
            it 'should return a Resource' do
              last = @collection.last
              last.should_not be_nil
              last.should be_kind_of(DataMapper::Resource)
              last.id.should == @steve.id
            end
          end

          describe 'with limit specified' do
            it 'should return a Collection' do
              collection = @collection.last(2)

              collection.should be_kind_of(DataMapper::Collection)
              collection.object_id.should_not == @collection.object_id

              collection.query.order.size.should == 1
              collection.query.order.first.property.should == @model.properties[:id]
              collection.query.order.first.direction.should == :desc

              collection.query.offset.should == 0
              collection.query.limit.should == 2

              collection.length.should == 2

              collection.entries.map { |r| r.id }.should == [ @bessie.id, @steve.id ]
            end

            it 'should return a Collection if limit is 1' do
              collection = @collection.last(1)

              collection.should be_kind_of(DataMapper::Collection)
              collection.object_id.should_not == @collection.object_id
            end
          end
        end

        describe '#load' do
          it 'should load resources from the identity map when possible' do
            @steve.collection = nil
            @repository.should_receive(:identity_map_get).with(@model, %w[ Steve ]).and_return(@steve)
            collection = DataMapper::Collection.new(@query)
            collection.load([ @steve.name, @steve.age ])
            collection.size.should == 1
            collection[0].object_id.should == @steve.object_id
            @steve.collection.object_id.should == collection.object_id
          end

          it 'should return a Resource' do
            @collection.load([ @steve.name, @steve.age ]).should be_kind_of(DataMapper::Resource)
          end
        end

        describe '#loaded?' do
          it 'should return true for an initialized collection' do
            @collection.should_not be_loaded
            @collection.to_a  # load collection
            @collection.should be_loaded
          end

          it 'should return false for an uninitialized collection' do
            @collection.should_not be_loaded
          end
        end

        describe '#pop' do
          it 'should reset the resource.collection' do
            @steve = @collection[2]

            @steve.collection.object_id.should == @collection.object_id
            @collection.pop
            @steve.collection.should be_nil
          end

          it 'should return a Resource' do
            @collection.pop.should be_kind_of(DataMapper::Resource)
          end
        end

        describe '#push' do
          it 'should return self' do
            @collection.push(@steve).object_id.should == @collection.object_id
          end
        end

        describe '#reject' do
          it 'should return a Collection with resources that did not match the block' do
            rejected = @collection.reject { |resource| false }
            rejected.should be_kind_of(DataMapper::Collection)
            rejected.object_id.should_not == @collection.object_id
            rejected.length.should == 3
            rejected[0].id.should == @nancy.id
            rejected[1].id.should == @bessie.id
            rejected[2].id.should == @steve.id
          end

          it 'should return an empty Collection if resources matched the block' do
            rejected = @collection.reject { |resource| true }
            rejected.should be_kind_of(DataMapper::Collection)
            rejected.object_id.should_not == @collection.object_id
            rejected.length.should == 0
          end
        end

        describe '#reject!' do
          it 'should return self if resources matched the block' do
            @collection.reject! { |resource| true }.object_id.should == @collection.object_id
          end

          it 'should return nil if no resources matched the block' do
            @collection.reject! { |resource| false }.should be_nil
          end
        end

        describe '#reload' do
          it 'should return self' do
            @collection.reload.object_id.should == @collection.object_id
          end

          it 'should replace the collection with the results of read_set' do
            original = @collection.dup
            @collection.reload.should == @collection
            @collection.should == original
          end

          it 'should reload lazily initialized fields' do
            pending 'Move to unit specs'

            @repository.should_receive(:all) do |model,query|
              model.should == @model

              query.should be_instance_of(DataMapper::Query)
              query.reload.should     == true
              query.offset.should     == 0
              query.limit.should      == 10
              query.order.should      == []
              query.fields.should     == @model.properties.defaults
              query.links.should      == []
              query.includes.should   == []
              query.conditions.should == [ [ :eql, @model.properties[:id], [ 1, 2, 3 ] ] ]

              @collection
            end

            @collection.reload
          end
        end

        describe '#replace' do
          it "should orphan each existing resource from the collection if loaded?" do
            entries = @collection.entries
            entries.each { |r| r.collection.object_id.should == @collection.object_id }
            @collection.replace([])
            entries.each { |r| r.collection.should be_nil }
          end

          it 'should relate each new resource to the collection' do
            @nancy.collection.object_id.should_not == @collection.object_id
            @collection.replace([ @nancy ])
            @nancy.collection.object_id.should == @collection.object_id
          end

          it 'should replace the contents of the collection' do
            other = [ @nancy ]
            @collection.should_not == other
            @collection.replace(other)
            @collection.should == other
            @collection.object_id.should_not == @other.object_id
          end
        end

        describe '#reverse' do
          [ true, false ].each do |loaded|
            describe "on a collection where loaded? == #{loaded}" do
              before do
                @collection.to_a if loaded
              end

              it 'should return a Collection with reversed entries' do
                reversed = @collection.reverse
                reversed.should be_kind_of(DataMapper::Collection)
                reversed.object_id.should_not == @collection.object_id
                reversed.entries.should == @collection.entries.reverse

                reversed.query.order.size.should == 1
                reversed.query.order.first.property.should == @model.properties[:id]
                reversed.query.order.first.direction.should == :desc
              end
            end
          end
        end

        describe '#reverse!' do
          it 'should return self' do
            @collection.reverse!.object_id.should == @collection.object_id
          end
        end

        describe '#reverse_each' do
          it 'should return self' do
            @collection.reverse_each { |resource| }.object_id.should == @collection.object_id
          end
        end

        describe '#select' do
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
          it 'should reset the resource.collection' do
            nancy  = @collection[0]

            nancy.collection.object_id.should == @collection.object_id
            @collection.shift
            nancy.collection.should be_nil
          end

          it 'should return a Resource' do
            @collection.shift.should be_kind_of(DataMapper::Resource)
          end
        end

        describe '#slice' do
          describe 'with an index' do
            it 'should return a Resource' do
              resource = @collection.slice(0)
              resource.should be_kind_of(DataMapper::Resource)
            end
          end

          describe 'with a start and length' do
            it 'should return a Collection' do
              nancy  = @collection[0]

              sliced = @collection.slice(0, 1)
              sliced.should be_kind_of(DataMapper::Collection)
              sliced.object_id.should_not == @collection.object_id
              sliced.length.should == 1
              sliced[0].should == nancy
            end
          end

          describe 'with a Range' do
            it 'should return a Collection' do
              nancy  = @collection[0]
              bessie = @collection[1]

              sliced = @collection.slice(0..1)
              sliced.should be_kind_of(DataMapper::Collection)
              sliced.object_id.should_not == @collection.object_id
              sliced.length.should == 2
              sliced[0].should == nancy
              sliced[1].should == bessie
            end
          end
        end

        describe '#slice!' do
          describe 'with an index' do
            it 'should return a Resource' do
              resource = @collection.slice!(0)
              resource.should be_kind_of(DataMapper::Resource)
            end
          end

          describe 'with a start and length' do
            it 'should return a Collection' do
              nancy = @collection[0]

              sliced = @collection.slice!(0, 1)
              sliced.should be_kind_of(DataMapper::Collection)
              sliced.object_id.should_not == @collection.object_id
              sliced.length.should == 1
              sliced[0].should == nancy
            end
          end

          describe 'with a Range' do
            it 'should return a Collection' do
              nancy  = @collection[0]
              bessie = @collection[1]

              sliced = @collection.slice(0..1)
              sliced.should be_kind_of(DataMapper::Collection)
              sliced.object_id.should_not == @collection.object_id
              sliced.length.should == 2
              sliced[0].should == nancy
              sliced[1].should == bessie
            end
          end
        end

        describe '#sort' do
          it 'should return a Collection' do
            sorted = @collection.sort { |a,b| a.age <=> b.age }
            sorted.should be_kind_of(DataMapper::Collection)
            sorted.object_id.should_not == @collection.object_id
          end
        end

        describe '#sort!' do
          it 'should return self' do
            @collection.sort! { |a,b| 0 }.object_id.should == @collection.object_id
          end
        end

        describe '#unshift' do
          it 'should return self' do
            @collection.unshift(@steve).object_id.should == @collection.object_id
          end
        end

        describe '#values_at' do
          it 'should return a Collection' do
            values = @collection.values_at(0)
            values.should be_kind_of(DataMapper::Collection)
            values.object_id.should_not == @collection.object_id
          end

          it 'should return a Collection of the resources at the index' do
            nancy = @collection[0]
            @collection.values_at(0).entries.should == [ nancy ]
          end
        end

        describe 'with lazy loading' do
          it "should take a materialization block" do
            collection = DataMapper::Collection.new(@query) do |c|
               c.should be_empty
               c.load(['Bob', 10])
               c.load(['Nancy', 11])
             end

             collection.length.should == 2
          end
        end
      end
    end
  end
end
