require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  class Orange
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :name, String, :key => true
    property :color, String
  end

  class Apple
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :id, Integer, :serial => true
    property :color, String, :default => 'green', :nullable => true
  end

  class FortunePig
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :id, Integer, :serial => true
    property :name, String

    def to_s
      name
    end

    after :create do
      @created_id = self.id
    end

    after :save do
      @save_id = self.id
    end
  end

  class Car
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :brand, String, :key => true
    property :color, String
    property :created_on, Date
    property :touched_on, Date
    property :updated_on, Date

    before :save do
      self.touched_on = Date.today
    end

    before :create do
      self.created_on = Date.today
    end

    before :update do
      self.updated_on = Date.today
    end
  end

  class Male
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :id, Integer, :serial => true
    property :name, String
    property :iq, Integer, :default => 100
    property :type, Discriminator
    property :data, Object

    def iq=(i)
      attribute_set(:iq, i - 1)
    end
  end

  class Bully < Male; end

  class Mugger < Bully; end

  class Maniac < Bully; end

  class Psycho < Maniac; end

  class Geek < Male
    property :awkward, Boolean, :default => true

    def iq=(i)
      attribute_set(:iq, i + 30)
    end
  end

  class Flanimal
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :id, Integer, :serial => true
    property :type, Discriminator
    property :name, String
  end

  class Sprog < Flanimal; end

  describe "DataMapper::Resource with #{ADAPTER}" do
    before :all do
      Orange.auto_migrate!(ADAPTER)
      Apple.auto_migrate!(ADAPTER)
      FortunePig.auto_migrate!(ADAPTER)

      orange = Orange.new(:color => 'orange')
      orange.name = 'Bob' # Keys are protected from mass-assignment by default.
      repository(ADAPTER) { orange.save }
    end

    it "should be able to overwrite Resource#to_s" do
      repository(ADAPTER) do
        ted = FortunePig.create!(:name => "Ted")
        FortunePig.get!(ted.id).to_s.should == 'Ted'
      end
    end
    
    it "should be able to destroy objects" do
      apple = Apple.create!(:color => 'Green')
      lambda do
        apple.destroy
      end.should_not raise_error
    end
    
    it "should be able to reload objects" do
      orange = repository(ADAPTER) { Orange.get!('Bob') }
      orange.color.should == 'orange'
      orange.color = 'blue'
      orange.color.should == 'blue'
      orange.reload!
      orange.color.should == 'orange'
    end

    it "should be able to reload new objects" do
      repository(ADAPTER) do
        Orange.create(:name => 'Tom').reload!
      end
    end

    it "should be able to find first or create objects" do
      repository(ADAPTER) do
        orange = Orange.create(:name => 'Naval')

        Orange.first_or_create(:name => 'Naval').should == orange

        purple = Orange.first_or_create(:name => 'Purple', :color => 'Fuschia')
        oranges = Orange.all(:name => 'Purple')
        oranges.size.should == 1
        oranges.first.should == purple
      end
    end

    it "should be able to override a default with a nil" do
      repository(ADAPTER) do
        apple = Apple.new
        apple.color = nil
        apple.save
        apple.color.should be_nil

        apple = Apple.create(:color => nil)
        apple.color.should be_nil
      end
    end

    it "should be able to respond to create hooks" do
      bob = repository(ADAPTER) { FortunePig.create(:name => 'Bob') }
      bob.id.should_not be_nil
      bob.instance_variable_get("@created_id").should == bob.id

      fred = FortunePig.new(:name => 'Fred')
      repository(ADAPTER) { fred.save }
      fred.id.should_not be_nil
      fred.instance_variable_get("@save_id").should == fred.id
    end

    it "should be dirty when Object properties are changed" do
      # pending "Awaiting Property#track implementation"
      repository(ADAPTER) do
        Male.auto_migrate!
      end
      repository(ADAPTER) do
        bob = Male.create(:name => "Bob", :data => {})
        bob.dirty?.should be_false
        bob.data.merge!(:name => "Bob")
        bob.dirty?.should be_true
        bob = Male.first
        bob.data[:name] = "Bob"
        bob.dirty?.should be_true
      end
    end

    describe "anonymity" do

      before :all do
        @planet = DataMapper::Resource.new("planet") do
          property :name, String, :key => true
          property :distance, Integer
        end

        @planet.auto_migrate!(ADAPTER)
      end

      it "should be able to persist" do
        repository(ADAPTER) do
          pluto = @planet.new
          pluto.name = 'Pluto'
          pluto.distance = 1_000_000
          pluto.save

          clone = @planet.get!('Pluto')
          clone.name.should == 'Pluto'
          clone.distance.should == 1_000_000
        end
      end

    end

    describe "hooking" do
      before :all do
        Car.auto_migrate!(ADAPTER)
      end

      it "should execute hooks before creating/updating objects" do
        repository(ADAPTER) do
          c1 = Car.new(:brand => 'BMW', :color => 'white')

          c1.new_record?.should == true
          c1.created_on.should == nil

          c1.save

          c1.new_record?.should == false
          c1.touched_on.should == Date.today
          c1.created_on.should == Date.today
          c1.updated_on.should == nil

          c1.color = 'black'
          c1.save

          c1.updated_on.should == Date.today
        end

      end

    end

    describe "inheritance" do
      before :all do
        Geek.auto_migrate!(ADAPTER)

        repository(ADAPTER) do
          Male.create!(:name => 'John Dorian')
          Bully.create!(:name => 'Bob', :iq => 69)
          Geek.create!(:name => 'Steve', :awkward => false, :iq => 132)
          Geek.create!(:name => 'Bill', :iq => 150)
          Bully.create!(:name => 'Johnson')
          Mugger.create!(:name => 'Frank')
          Maniac.create!(:name => 'William')
          Psycho.create!(:name => 'Norman')
        end

        Flanimal.auto_migrate!(ADAPTER)

      end

      it "should test bug ticket #302" do
        repository(ADAPTER) do
          Sprog.create(:name => 'Marty')
          Sprog.first(:name => 'Marty').should_not be_nil
        end
      end

      it "should select appropriate types" do
        repository(ADAPTER) do
          males = Male.all
          males.should have(8).entries

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
        repository(ADAPTER) do
          Male.first(:name => 'John Dorian').should be_a_kind_of(Male)
          Geek.first(:name => 'John Dorian').should be_nil
          Geek.first.iq.should > Bully.first.iq
        end
      end

      it "should select objects of all inheriting classes" do
        repository(ADAPTER) do
          Male.all.should have(8).entries
          Geek.all.should have(2).entries
          Bully.all.should have(5).entries
          Mugger.all.should have(1).entries
          Maniac.all.should have(2).entries
          Psycho.all.should have(1).entries
        end
      end

      it "should inherit setter method from parent" do
        repository(ADAPTER) do
          Bully.first(:name => "Bob").iq.should == 68
        end
      end

      it "should be able to overwrite a setter in a child class" do
        repository(ADAPTER) do
          Geek.first(:name => "Bill").iq.should == 180
        end
      end
    end
  end
end
