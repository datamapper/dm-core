require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if HAS_SQLITE3
  describe "DataMapper::Resource" do

    before(:all) do
      class Orange
        include DataMapper::Resource
        property :name, String, :key => true
        property :color, String
      end

      Orange.auto_migrate!(:sqlite3)
      orange = Orange.new(:color => 'orange')
      orange.name = 'Bob' # Keys are protected from mass-assignment by default.
      repository(:sqlite3) { orange.save }
    end

    it "should be able to reload objects" do
      orange = repository(:sqlite3) { Orange['Bob'] }
      orange.color.should == 'orange'
      orange.color = 'blue'
      orange.color.should == 'blue'
      orange.reload!
      orange.color.should == 'orange'
    end

    describe "anonymity" do

      before(:all) do
        @planet = DataMapper::Resource.new("planet") do
          property :name, String, :key => true
          property :distance, Fixnum
        end

        @planet.auto_migrate!(:sqlite3)
      end

      it "should be able to persist" do
        repository(:sqlite3) do
          pluto = @planet.new
          pluto.name = 'Pluto'
          pluto.distance = 1_000_000
          pluto.save

          clone = @planet['Pluto']
          clone.name.should == 'Pluto'
          clone.distance.should == 1_000_000
        end
      end

    end

    describe "inheritance" do
      before(:all) do
        class Male
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :name, String
          property :iq, Fixnum, :default => 100
          property :type, Class, :default => lambda { |r,p| p.model }
        end

        class Bully < Male
          # property :brutal, Boolean, :default => true
          # Automigrate should add fields for all subclasses of an STI-model, but currently it does not.
        end

        class Mugger < Bully

        end

        class Maniac < Bully

        end

        class Geek < Male
          property :awkward, Boolean, :default => true
        end

        Geek.auto_migrate!(:sqlite3)

        repository(:sqlite3) do
          Male.create!(:name => 'John Dorian')
          Bully.create!(:name => 'Bob')
          Geek.create!(:name => 'Steve', :awkward => false, :iq => 132)
          Geek.create!(:name => 'Bill', :iq => 150)
          Bully.create!(:name => 'Johnson')
          Mugger.create!(:name => 'Frank')
          Maniac.create!(:name => 'William')
        end
      end

      it "should select appropriate types" do
        repository(:sqlite3) do
          males = Male.all
          males.should have(7).entries

          males.each do |male|
            male.class.name.should == male.type.name
          end

          Male.first(:name => 'Steve').should be_a_kind_of(Geek)
          Bully.first(:name => 'Bob').should be_a_kind_of(Bully)
          Geek.first(:name => 'Steve').should be_a_kind_of(Geek)
          Geek.first(:name => 'Bill').should be_a_kind_of(Geek)
          Bully.first(:name => 'Johnson').should be_a_kind_of(Bully)
          Male.first(:name => 'John Dorian').should be_a_kind_of(Male)
        end
      end

      it "should not select parent type" do
        pending("Bug...")
        repository(:sqlite3) do
          Male.first(:name => 'John Dorian').should be_a_kind_of(Male)
          Geek.first(:name => 'John Dorian').should be_nil
          Geek.first.iq.should > Bully.first.iq # now its matching Male#1 against Male#1
        end
      end

      it "should select objects of all subtypes of type" do
        pending("Implementation...")
        repository(:sqlite3) do
          Male.all.should have(7).entries
          Bully.all.should have(3).entries
          Mugger.all.should have(1).entries
          Maniac.all.should have(1).entries
        end
      end
    end
  end
end
