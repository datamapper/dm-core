require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

gem 'fastercsv', '>=1.2.3'
require 'fastercsv'

if ADAPTER
  describe DataMapper::Property, "with #{ADAPTER}" do
    describe " tracking strategies" do
      before :all do
        class Actor
          include DataMapper::Resource

          property :id, Integer, :serial => true
          property :name, String, :lock => true
          property :notes, DataMapper::Types::Text, :track => false
          property :age, Integer, :track => :set
          property :rating, Integer # :track default should be false for immutable types
          property :location, String # :track default should be :get for mutable types
          property :lead, TrueClass, :track => :load
          property :agent, String, :track => :hash # :track only Object#hash value on :load.
            # Potentially faster, but less safe, so use judiciously, when the odds of a hash-collision are low.
        end
      end

      before do
        Actor.auto_migrate!(ADAPTER)
      end

      it "false" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end

      it ":load" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end

      it ":hash" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end

      it ":get" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end

      it ":set" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end
    end

    describe "lazy loading" do
      before :all do
        class SailBoat
          include DataMapper::Resource
          property :id, Integer, :serial => true
          property :notes, String, :lazy => [:notes]
          property :trip_report, String, :lazy => [:notes,:trip]
          property :miles, Integer, :lazy => [:trip]
        end
      end

      before do
        SailBoat.auto_migrate!(ADAPTER)

        repository(ADAPTER) do
          SailBoat.create!(:id => 1, :notes=>'Note',:trip_report=>'Report',:miles=>23)
          SailBoat.create!(:id => 2, :notes=>'Note',:trip_report=>'Report',:miles=>23)
          SailBoat.create!(:id => 3, :notes=>'Note',:trip_report=>'Report',:miles=>23)
        end
      end

      it "should lazy load in context" do
        result = repository(ADAPTER) do
          SailBoat.all
        end

        result[0].instance_variables.should_not include('@notes')
        result[0].instance_variables.should_not include('@trip_report')
        result[1].instance_variables.should_not include('@notes')
        result[0].notes.should_not be_nil
        result[1].instance_variables.should include('@notes')
        result[1].instance_variables.should include('@trip_report')
        result[1].instance_variables.should_not include('@miles')

        result = repository(ADAPTER) do
          SailBoat.all
        end

        result[0].instance_variables.should_not include('@trip_report')
        result[0].instance_variables.should_not include('@miles')

        result[1].trip_report.should_not be_nil
        result[2].instance_variables.should include('@miles')
      end
    end

    describe 'defaults' do
      before :all do
        class Catamaran
          include DataMapper::Resource
          property :id, Integer, :serial => true
          property :name, String

          # Boolean
          property :could_be_bool0, TrueClass, :default => true
          property :could_be_bool1, TrueClass, :default => false
        end

        repository(ADAPTER){ Catamaran.auto_migrate!(ADAPTER) }
      end

      before :each do
        @cat = Catamaran.new
      end

      it "should have defaults" do
        @cat.could_be_bool0.should == true
        @cat.could_be_bool1.should_not be_nil
        @cat.could_be_bool1.should == false

        @cat.name = 'Mary Mayweather'

        repository(ADAPTER) do
          @cat.save

          cat = Catamaran.first
          cat.could_be_bool0.should == true
          cat.could_be_bool1.should_not be_nil
          cat.could_be_bool1.should == false
          cat.destroy
        end

      end

      it "should have defaults even with creates" do
        repository(ADAPTER) do
          Catamaran.create!(:name => 'Jingle All The Way')
          cat = Catamaran.first
          cat.name.should == 'Jingle All The Way'
          cat.could_be_bool0.should == true
          cat.could_be_bool1.should_not be_nil
          cat.could_be_bool1.should == false
        end
      end
    end
  end
end
