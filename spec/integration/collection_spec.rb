require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  describe 'association proxying' do
    before :all do
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

      Zebra.auto_migrate!(ADAPTER)
      Stripe.auto_migrate!(ADAPTER)

      repository(ADAPTER) do
        nancy  = Zebra.new(:age => 11, :notes => 'Spotted!')
        nancy.name = 'Nance'
        nancy.save

        bessie = Zebra.new(:age => 10, :notes => 'Striped!')
        bessie.name = 'Bessie'
        bessie.save

        steve  = Zebra.new(:age => 8, :notes => 'Bald!')
        steve.name = 'Steve'
        steve.save

        @babe      = Stripe.new
        @babe.name = 'Babe'
        @babe.save

        @snowball  = Stripe.new
        @snowball.name = 'snowball'
        @snowball.save

        nancy.stripes << @babe
        nancy.stripes << @snowball
      end
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
end
