require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  describe DataMapper::Query, "with #{ADAPTER}" do
    describe 'when ordering' do
      before :all do
        class SailBoat
          include DataMapper::Resource
          property :id, Integer, :serial => true
          property :name, String
          property :port, String
        end
      end

      before do
        SailBoat.auto_migrate!(ADAPTER)

        repository(ADAPTER) do
          SailBoat.create!(:name => 'A', :port => 'C')
          SailBoat.create!(:name => 'B', :port => 'B')
          SailBoat.create!(:name => 'C', :port => 'A')
        end
      end

      it "should find by conditions" do
        lambda do
          repository(ADAPTER) do
            SailBoat.first(:conditions => ['name = ?', 'B'])
          end
        end.should_not raise_error

        lambda do
          repository(ADAPTER) do
            SailBoat.first(:conditions => ['name = ?', 'A'])
          end
        end.should_not raise_error
      end

      it "should find by conditions passed in as hash" do
        repository(ADAPTER) do
          SailBoat.create!(:name => "couldbe@email.com", :port => 'wee')

          find = SailBoat.first(:name => 'couldbe@email.com')
          find.name.should == 'couldbe@email.com'

          find = SailBoat.first(:name => 'couldbe@email.com', :port.not => nil)
          find.should_not be_nil
          find.port.should_not be_nil
          find.name.should == 'couldbe@email.com'
        end
      end

      it "should find by conditions passed in a range" do
        repository(ADAPTER) do
          find = SailBoat.all(:id => 0..2)
          find.should_not be_nil
          find.should have(2).entries

          find = SailBoat.all(:id.not => 0..2)
          find.should have(1).entries
        end
      end

      it "should order results" do
        repository(ADAPTER) do
          result = SailBoat.all(:order => [
            DataMapper::Query::Direction.new(SailBoat.properties[:name], :asc)
          ])
          result[0].id.should == 1

          result = SailBoat.all(:order => [
            DataMapper::Query::Direction.new(SailBoat.properties[:port], :asc)
          ])
          result[0].id.should == 3

          result = SailBoat.all(:order => [
            DataMapper::Query::Direction.new(SailBoat.properties[:name], :asc),
            DataMapper::Query::Direction.new(SailBoat.properties[:port], :asc)
          ])
          result[0].id.should == 1

          result = SailBoat.all(:order => [
            SailBoat.properties[:name],
            DataMapper::Query::Direction.new(SailBoat.properties[:port], :asc)
          ])
          result[0].id.should == 1

          result = SailBoat.all(:order => [:name])
          result[0].id.should == 1

          result = SailBoat.all(:order => [:name.desc])
          result[0].id.should == 3
        end
      end
    end

    describe 'when sub-selecting' do
      before :all do
        class Permission
          include DataMapper::Resource
          property :id, Integer, :serial => true
          property :user_id, Integer
          property :resource_id, Integer
          property :resource_type, String
          property :token, String
        end

        class SailBoat
          include DataMapper::Resource
          property :id, Integer, :serial => true
          property :name, String
          property :port, String
          property :captain, String
        end
      end

      before do
        Permission.auto_migrate!(ADAPTER)
        SailBoat.auto_migrate!(ADAPTER)

        repository(ADAPTER) do
          SailBoat.create!(:id => 1, :name => "Fantasy I",      :port => "Cape Town", :captain => 'Joe')
          SailBoat.create!(:id => 2, :name => "Royal Flush II", :port => "Cape Town", :captain => 'James')
          SailBoat.create!(:id => 3, :name => "Infringer III",  :port => "Cape Town", :captain => 'Jason')

          #User 1 permission -- read boat 1 & 2
          Permission.create!(:id => 1, :user_id => 1, :resource_id => 1, :resource_type => 'SailBoat', :token => 'READ')
          Permission.create!(:id => 2, :user_id => 1, :resource_id => 2, :resource_type => 'SailBoat', :token => 'READ')

          #User 2 permission  -- read boat 2 & 3
          Permission.create!(:id => 3, :user_id => 2, :resource_id => 2, :resource_type => 'SailBoat', :token => 'READ')
          Permission.create!(:id => 4, :user_id => 2, :resource_id => 3, :resource_type => 'SailBoat', :token => 'READ')
        end
      end

      it 'should accept a DM::Query as a value of a condition' do
        # User 1
        acl = DataMapper::Query.new(repository(ADAPTER), Permission, :user_id => 1, :resource_type => 'SailBoat', :token => 'READ', :fields => [ :resource_id ])
        query = { :port => 'Cape Town', :id => acl, :captain.like => 'J%', :order => [ :id ] }
        boats = repository(ADAPTER) { SailBoat.all(query) }
        boats.should have(2).entries
        boats.entries[0].id.should == 1
        boats.entries[1].id.should == 2

        # User 2
        acl = DataMapper::Query.new(repository(ADAPTER), Permission, :user_id => 2, :resource_type => 'SailBoat', :token => 'READ', :fields => [ :resource_id ])
        query = { :port => 'Cape Town', :id => acl, :captain.like => 'J%', :order => [ :id ] }
        boats = repository(ADAPTER) { SailBoat.all(query) }

        boats.should have(2).entries
        boats.entries[0].id.should == 2
        boats.entries[1].id.should == 3
      end

      it 'when value is NOT IN another query' do
        # Boats that User 1 Cannot see
        acl = DataMapper::Query.new(repository(ADAPTER), Permission, :user_id => 1, :resource_type => 'SailBoat', :token => 'READ', :fields => [:resource_id])
        query = { :port => 'Cape Town', :id.not => acl, :captain.like => 'J%' }
        boats = repository(ADAPTER) { SailBoat.all(query) }
        boats.should have(1).entries
        boats.entries[0].id.should == 3
      end
    end  # describe sub-selecting

    describe 'when linking associated objects' do
      before :all do
        class Region
          include DataMapper::Resource
          property :id, Integer, :serial => true
          property :name, String

          def self.default_repository_name
            ADAPTER
          end
        end

        class Factory
          include DataMapper::Resource
          property :id, Integer, :serial => true
          property :region_id, Integer
          property :name, String

          repository(:mock) do
            property :land, String
          end

          belongs_to :region

          def self.default_repository_name
            ADAPTER
          end
        end

        class Vehicle
          include DataMapper::Resource
          property :id, Integer, :serial => true
          property :factory_id, Integer
          property :name, String

          belongs_to :factory

          def self.default_repository_name
            ADAPTER
          end
        end
        
        module Namespace
          class Region
            include DataMapper::Resource
            property :id, Integer, :serial => true
            property :name, String

            def self.default_repository_name
              ADAPTER
            end
          end
          
          class Factory
            include DataMapper::Resource
            property :id, Integer, :serial => true
            property :region_id, Integer
            property :name, String

            repository(:mock) do
              property :land, String
            end

            belongs_to :region

            def self.default_repository_name
              ADAPTER
            end
          end

          class Vehicle
            include DataMapper::Resource
            property :id, Integer, :serial => true
            property :factory_id, Integer
            property :name, String

            belongs_to :factory

            def self.default_repository_name
              ADAPTER
            end
          end
        end
      end

      before do
        Region.auto_migrate!
        Factory.auto_migrate!
        Vehicle.auto_migrate!

        Region.new(:id=>1, :name=>'North West').save
        Factory.new(:id=>2000, :region_id=>1, :name=>'North West Plant').save
        Vehicle.new(:id=>1, :factory_id=>2000, :name=>'10 ton delivery truck').save
        
        Namespace::Region.auto_migrate!
        Namespace::Factory.auto_migrate!
        Namespace::Vehicle.auto_migrate!
        
        Namespace::Region.new(:id=>1, :name=>'North West').save
        Namespace::Factory.new(:id=>2000, :region_id=>1, :name=>'North West Plant').save
        Namespace::Vehicle.new(:id=>1, :factory_id=>2000, :name=>'10 ton delivery truck').save
      end

      it 'should require that all properties in :fields and all :links come from the same repository' #do
      #  land = Factory.properties(:mock)[:land]
      #  fields = []
      #  Vehicle.properties(ADAPTER).map do |property|
      #    fields << property
      #  end
      #  fields << land
      #
      #  lambda{
      #    begin
      #      results = repository(ADAPTER) { Vehicle.all(:links => [:factory], :fields => fields) }
      #    rescue RuntimeError
      #      $!.message.should == "Property Factory.land not available in repository #{ADAPTER}"
      #      raise $!
      #    end
      #  }.should raise_error(RuntimeError)
      #end

      it 'should accept a DM::Assoc::Relationship as a link' do
        factory = DataMapper::Associations::Relationship.new(
          :factory,
          ADAPTER,
          'Vehicle',
          'Factory',
          { :child_key => [ :factory_id ], :parent_key => [ :id ] }
        )
        results = repository(ADAPTER) { Vehicle.all(:links => [factory]) }
        results.should have(1).entries
      end

      it 'should accept a symbol of an association name as a link' do
        results = repository(ADAPTER) { Vehicle.all(:links => [:factory]) }
        results.should have(1).entries
      end

      it 'should accept a string of an association name as a link' do
        results = repository(ADAPTER) { Vehicle.all(:links => ['factory']) }
        results.should have(1).entries
      end

      it 'should accept a mixture of items as a set of links' do
        region = DataMapper::Associations::Relationship.new(
          :region,
          ADAPTER,
          'Factory',
          'Region',
          { :child_key => [ :region_id ], :parent_key => [ :id ] }
        )
        results = repository(ADAPTER) { Vehicle.all(:links => ['factory',region]) }
        results.should have(1).entries
      end

      it 'should only accept a DM::Assoc::Relationship, String & Symbol as a link' do
        lambda{
          DataMapper::Query.new(repository(ADAPTER), Vehicle, :links => [1])
        }.should raise_error(ArgumentError)
      end

      it 'should have a association by the name of the Symbol or String' do
        lambda{
          DataMapper::Query.new(repository(ADAPTER), Vehicle, :links=>['Sailing'])
        }.should raise_error(ArgumentError)

        lambda{
          DataMapper::Query.new(repository(ADAPTER), Vehicle, :links=>[:sailing])
        }.should raise_error(ArgumentError)
      end

      it 'should create an n-level query path' do
        Vehicle.factory.region.model.should == Region
        Vehicle.factory.region.name.property.should == Region.properties(Region.repository.name)[:name]
      end

      it 'should accept a DM::QueryPath as the key to a condition' do
        vehicle = Vehicle.first(Vehicle.factory.region.name => 'North West')
        vehicle.name.should == '10 ton delivery truck'
        
        vehicle = Namespace::Vehicle.first(Namespace::Vehicle.factory.region.name => 'North West')
        vehicle.name.should == '10 ton delivery truck'
      end

      it "should accept a string representing a DM::QueryPath as they key to a condition" do
        vehicle = Vehicle.first("factory.region.name" => 'North West')
        vehicle.name.should == '10 ton delivery truck'
      end

      it 'should auto generate the link if a DM::Property from a different resource is in the :fields option'

      it 'should create links with composite keys'

      it 'should eager load associations' do
        repository(ADAPTER) do
          vehicle = Vehicle.first(:includes => [Vehicle.factory])
        end
      end
    end   # describe links
  end # DM::Query
end
