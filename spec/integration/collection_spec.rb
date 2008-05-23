require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  describe 'association proxying' do
    before(:all) do

      class Zebra
        include DataMapper::Resource

        def self.default_repository_name
          ADAPTER
        end

        property :id, Integer, :serial => true
        property :name, String
        property :age, Integer
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

        nancy  = Zebra.new(:age => 11)
        nancy.name = 'nance'
        nancy.save

        bessie = Zebra.new(:age => 10)
        bessie.name = 'Bessie'
        bessie.save

        steve  = Zebra.new(:age => 8)
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

    it "should proxy the relationships of the model" do
      repository(ADAPTER) do
        zebras = Zebra.all
        zebras.should have(3).entries
        zebras.find { |zebra| zebra.name == 'nance' }.stripes.should have(2).entries
        zebras.stripes.should == [@babe, @snowball]
      end
    end
  end

end
