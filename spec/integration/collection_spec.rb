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
        @nancy  = Zebra.create(:name => 'Nance',  :age => 11, :notes => 'Spotted!')
        @bessie = Zebra.create(:name => 'Bessie', :age => 10, :notes => 'Striped!')
        @steve  = Zebra.create(:name => 'Steve',  :age => 8,  :notes => 'Bald!')

        @babe      = Stripe.new
        @babe.name = 'Babe'
        @babe.save

        @snowball  = Stripe.new
        @snowball.name = 'snowball'
        @snowball.save

        @nancy.stripes << @babe
        @nancy.stripes << @snowball
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
        zebras = Zebra.all(:order => [:name])
        zebras.query.order.should == [DataMapper::Query::Direction.new(Zebra.properties(ADAPTER)[:name])]
      end
    end

    it "should proxy the relationships of the model" do
      repository(ADAPTER) do
        zebras = Zebra.all
        zebras.should have(3).entries
        zebras.find { |zebra| zebra.name == 'Nance' }.stripes.should have(2).entries
        zebras.stripes.should == [@babe, @snowball]
      end
    end

    it "should preserve it's order on reload" do
      repository(ADAPTER) do |r|
        zebras = Zebra.all(:order => [:name])

        order = %w{ Bessie Nance Steve }

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
      query = DataMapper::Query.new(repository(ADAPTER), Zebra)

      @collection = DataMapper::Collection.new(query)
    end

    describe '#first' do
      describe 'with no arguments' do
        it 'should return a Resource' do
          first = @collection.first
          first.should_not be_nil
          first.should be_kind_of(DataMapper::Resource)
        end
      end

      describe 'with number of results specified' do
        it 'should return a Collection ' do
          @collection.query.offset.should == 0
          @collection.query.limit.should be_nil

          collection = @collection.first(2)
          collection.should be_kind_of(DataMapper::Collection)
          collection.object_id.should_not == @collection.object_id
          collection.query.offset.should == 0
          collection.query.limit.should == 2
          collection.length.should == 2
          collection[0].should == @nancy
          collection[1].should == @bessie
        end
      end
    end

    describe '#last' do
      describe 'with no arguments' do
        it 'should return a Resource' do
          last = @collection.last
          last.should_not be_nil
          last.should be_kind_of(DataMapper::Resource)
        end
      end

      describe 'with number of results specified' do
        it 'should return a Collection ' do
          @collection.query.offset.should == 0
          @collection.query.limit.should be_nil

          collection = @collection.last(2)
          collection.should be_kind_of(DataMapper::Collection)
          collection.object_id.should_not == @collection.object_id
          collection.query.offset.should == 0
          collection.query.limit.should == 2
          collection.length.should == 2
          collection[0].should == @bessie
          collection[1].should == @steve
        end
      end
    end
  end
end
