require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Property do
  describe " tracking strategies" do
    before :all do
      class Actor
        include DataMapper::Resource

        property :id, Serial
        property :name, String, :track => :set # :track default is :get for mutable types
        property :notes, DataMapper::Types::Text
        property :age, Integer # :track default is :set for immutable types
        property :rating, Integer
        property :location, String
        property :lead, TrueClass, :track => :load
        property :cv, Object # :track should be :hash
        property :agent, String, :track => :hash # :track only Object#hash value on :load.
        # Potentially faster, but less safe, so use judiciously, when the odds of a hash-collision are low.
      end
    end

    it "should set up tracking information" do
      Actor.properties[:name].track.should == :set
      Actor.properties[:location].track.should == :get
      Actor.properties[:rating].track.should == :set
      Actor.properties[:lead].track.should == :load
      Actor.properties[:cv].track.should == :hash
      Actor.properties[:agent].track.should == :hash
    end

    it "should track on :set" do
      bob = Actor.new(:name => 'bob')
      bob.save

      bob.original_values.should_not have_key(:name)
      bob.dirty?.should == false

      bob.name = "Bob"
      bob.original_values.should have_key(:name)
      bob.original_values[:name].should == 'bob'
      bob.dirty?.should == true
    end

    it "should track on :get" do
      jon = Actor.new(:name => 'jon', :location => 'dallas')
      jon.save

      jon.location
      jon.original_values.should have_key(:location)
      jon.original_values[:location].should == 'dallas'

      jon.dirty?.should be_false
      jon.save.should be_false

      jon.location.upcase!
      jon.location.should == 'DALLAS'
      jon.original_values[:location].should == 'dallas'

      jon.dirty?.should be_true
      jon.save.should be_true

      jon.location << '!'
      jon.original_values[:location].should == 'DALLAS'
      jon.dirty?.should be_true
    end

    it "should track on :load" do
      jan = Actor.create(:name => 'jan', :lead => true)
      jan.lead = false
      jan.original_values[:lead].should be_true
      jan.dirty?.should == true
      jan = Actor.first
      jan.original_values.should have_key(:lead)
      jan.original_values[:lead].should be_true
      jan.dirty?.should == false
    end

    it "should track on :hash" do
      cv = { 2005 => "Othello" }
      tom = Actor.create(:name => 'tom', :cv => cv)
      tom = Actor.first(:name => 'tom')
      tom.cv.merge!({2006 => "Macbeth"})

      tom.original_values.should have_key(:cv)
      # tom.original_values[:cv].should == cv.hash
      tom.cv.should == { 2005 => "Othello", 2006 => "Macbeth" }
      tom.dirty?.should == true
    end

    it "should track with lazy text fields (#342)" do
      tim = Actor.create(:name => 'tim')
      tim = Actor.first(:name => 'tim')
      tim.notes # make sure they're loaded...
      tim.dirty?.should be_false
      tim.save.should be_false
      tim.notes = "Testing"
      tim.dirty?.should be_true
      tim.save
      tim = Actor.first(:name => 'tim')
      tim.notes.should == "Testing"
    end
  end

  describe "lazy loading" do
    before :all do
      class RowBoat
        include DataMapper::Resource
        property :id, Serial
        property :notes, String, :lazy => [:notes]
        property :trip_report, String, :lazy => [:notes,:trip]
        property :miles, Integer, :lazy => [:trip]
      end
    end

    before do
      RowBoat.create(:id => 1, :notes=>'Note',:trip_report=>'Report',:miles=>23)
      RowBoat.create(:id => 2, :notes=>'Note',:trip_report=>'Report',:miles=>23)
      RowBoat.create(:id => 3, :notes=>'Note',:trip_report=>'Report',:miles=>23)
    end

    it "should lazy load in context" do
      result = RowBoat.all.to_a

      result[0].attribute_loaded?(:notes).should be_false
      result[0].attribute_loaded?(:trip_report).should be_false
      result[1].attribute_loaded?(:notes).should be_false

      result[0].notes.should_not be_nil

      result[1].attribute_loaded?(:notes).should be_true
      result[1].attribute_loaded?(:trip_report).should be_true
      result[1].attribute_loaded?(:miles).should be_false

      RowBoat.all.to_a

      result[0].attribute_loaded?(:trip_report).should be_false
      result[0].attribute_loaded?(:miles).should be_false

      result[1].trip_report.should_not be_nil
      result[2].attribute_loaded?(:miles).should be_true
    end

    it "should lazy load on Property#set" do
      boat = RowBoat.first
      boat.attribute_loaded?(:notes).should be_false
      boat.notes = 'New Note'
      boat.original_values[:notes].should == "Note"
    end
  end

  describe 'defaults' do
    before :all do
      class Catamaran
        include DataMapper::Resource
        property :id, Serial
        property :name, String

        # Boolean
        property :could_be_bool0, TrueClass, :default => true
        property :could_be_bool1, TrueClass, :default => false
      end
    end

    before :each do
      @cat = Catamaran.new
    end

    it "should have defaults" do
      @cat.could_be_bool0.should == true
      @cat.could_be_bool1.should_not be_nil
      @cat.could_be_bool1.should == false

      @cat.name = 'Mary Mayweather'

      @cat.save

      cat = Catamaran.first
      cat.could_be_bool0.should == true
      cat.could_be_bool1.should_not be_nil
      cat.could_be_bool1.should == false
      cat.destroy

    end

    it "should have defaults even with creates" do
      Catamaran.create(:name => 'Jingle All The Way')
      cat = Catamaran.first
      cat.name.should == 'Jingle All The Way'
      cat.could_be_bool0.should == true
      cat.could_be_bool1.should_not be_nil
      cat.could_be_bool1.should == false
    end
  end
end
