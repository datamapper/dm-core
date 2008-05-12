require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if HAS_SQLITE3
  describe DataMapper::Query do
    describe 'when ordering' do
      before do
        @adapter = repository(:sqlite3).adapter

        class SailBoat
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :name, String
          property :port, String
        end

        SailBoat.auto_migrate!(:sqlite3)

        repository(:sqlite3) do
          SailBoat.create(:id => 1, :name => "A", :port => "C")
          SailBoat.create(:id => 2, :name => "B", :port => "B")
          SailBoat.create(:id => 3, :name => "C", :port => "A")
        end
      end

      it "should find by conditions" do
        lambda do
          repository(:sqlite3) do
            SailBoat.first(:conditions => ['name = ?', 'B'])
          end
        end.should_not raise_error

        lambda do
          repository(:sqlite3) do
            SailBoat.first(:conditions => ['name = ?', 'A'])
          end
        end.should_not raise_error
      end
      
      it "should find by conditions passed in as hash" do
        repository(:sqlite3) do
          SailBoat.create(:name => "couldbe@email.com", :port => 1)
          
          find = SailBoat.first(:name => 'couldbe@email.com')
          find.name.should == 'couldbe@email.com'
      
          find = SailBoat.first(:name => 'couldbe@email.com', :port.not => nil)
          find.should_not be_nil
          find.port.should_not be_nil
          find.name.should == 'couldbe@email.com'
        end
        
      end

      it "should order results" do
        repository(:sqlite3) do
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

      after do
        @adapter.execute('DROP TABLE "sail_boats"')
      end
    end

    describe 'when sub-selecting' do
      before do
        @adapter = repository(:sqlite3).adapter

        class Permission
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :user_id, Fixnum
          property :resource_id, Fixnum
          property :resource_type, String
          property :token, String
        end

        class SailBoat
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :name, String
          property :port, String
          property :captain, String
        end

        Permission.auto_migrate!(:sqlite3)
        SailBoat.auto_migrate!(:sqlite3)

        repository(:sqlite3) do
          SailBoat.create(:id => 1, :name => "Fantasy I",      :port => "Cape Town", :captain => 'Joe')
          SailBoat.create(:id => 2, :name => "Royal Flush II", :port => "Cape Town", :captain => 'James')
          SailBoat.create(:id => 3, :name => "Infringer III",  :port => "Cape Town", :captain => 'Jason')

          #User 1 permission -- read boat 1 & 2
          Permission.create(:id => 1, :user_id => 1, :resource_id => 1, :resource_type => 'SailBoat', :token => 'READ')
          Permission.create(:id => 2, :user_id => 1, :resource_id => 2, :resource_type => 'SailBoat', :token => 'READ')

          #User 2 permission  -- read boat 2 & 3
          Permission.create(:id => 3, :user_id => 2, :resource_id => 2, :resource_type => 'SailBoat', :token => 'READ')
          Permission.create(:id => 4, :user_id => 2, :resource_id => 3, :resource_type => 'SailBoat', :token => 'READ')
        end
      end

      it 'should accept a DM::Query as a value of a condition' do
        # User 1
        acl = DataMapper::Query.new(repository(:sqlite3), Permission, :user_id => 1, :resource_type => 'SailBoat', :token => 'READ', :fields => [:resource_id])
        query = DataMapper::Query.new(repository(:sqlite3), SailBoat, :port => 'Cape Town',:id => acl,:captain.like => 'J%')
        boats = @adapter.read_set(repository(:sqlite3),query)
        boats.should have(2).entries
        boats.entries[0].id.should == 1
        boats.entries[1].id.should == 2

        # User 2
        acl = DataMapper::Query.new(repository(:sqlite3), Permission, :user_id => 2, :resource_type => 'SailBoat', :token => 'READ', :fields => [:resource_id])
        query = DataMapper::Query.new(repository(:sqlite3), SailBoat, :port => 'Cape Town',:id => acl,:captain.like => 'J%')
        boats = @adapter.read_set(repository(:sqlite3),query)
        boats.should have(2).entries
        boats.entries[0].id.should == 2
        boats.entries[1].id.should == 3
      end

      it 'when value is NOT IN another query' do
        # Boats that User 1 Cannot see
        acl = DataMapper::Query.new(repository(:sqlite3), Permission, :user_id => 1, :resource_type => 'SailBoat', :token => 'READ', :fields => [:resource_id])
        query = DataMapper::Query.new(repository(:sqlite3), SailBoat, :port => 'Cape Town',:id.not => acl,:captain.like => 'J%')
        boats = @adapter.read_set(repository(:sqlite3),query)
        boats.should have(1).entries
        boats.entries[0].id.should == 3
      end

      after do
        @adapter.execute('DROP TABLE "sail_boats"')
        @adapter.execute('DROP TABLE "permissions"')
      end
    end  # describe sub-selecting

    describe 'when linking associated objects' do
      before do
        @adapter = repository(:sqlite3).adapter

        class Region
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :name, String

          def self.default_repository_name
            :sqlite3
          end
        end

        class Factory
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :region_id, Fixnum
          property :name, String

          repository(:mock) do
            property :land, String
          end

          many_to_one :region

          def self.default_repository_name
            :sqlite3
          end
        end

        class Vehicle
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :factory_id, Fixnum
          property :name, String

          many_to_one :factory

          def self.default_repository_name
            :sqlite3
          end
        end

        Region.auto_migrate!
        Factory.auto_migrate!
        Vehicle.auto_migrate!

        Region.new(:id=>1,:name=>'North West').save
        Factory.new(:id=>2000,:region_id=>1,:name=>'North West Plant').save
        Vehicle.new(:id=>1,:factory_id=>2000,:name=>'10 ton delivery truck').save
      end

      it 'should require that all properties in :fields and all :links come from the same repository'
      #      do
      #        land = Factory.properties(:mock)[:land]
      #        fields = []
      #        Vehicle.properties(:sqlite3).map do |property|
      #          fields << property
      #        end
      #        fields << land
      #
      #        lambda{
      #          begin
      #            repository(:sqlite3) do
      #              query = DataMapper::Query.new(repository(:sqlite3), Vehicle,:links => [:factory], :fields => fields)
      #              results = @adapter.read_set(repository(:sqlite3), query)
      #            end
      #          rescue RuntimeError
      #            $!.message.should == 'Property Factory.land not available in repository sqlite3.'
      #            raise $!
      #          end
      #        }.should raise_error(RuntimeError)
      #      end

      it 'should accept a DM::Assoc::Relationship as a link' do
        factory = DataMapper::Associations::Relationship.new(
          :factory,
          :sqlite3,
          'Vehicle',
          'Factory',
          { :child_key => [ :factory_id ], :parent_key => [ :id ] }
        )
        query = DataMapper::Query.new(repository(:sqlite3), Vehicle,:links => [factory])
        results = @adapter.read_set(repository(:sqlite3), query)
        results.should have(1).entries
      end

      it 'should accept a symbol of an association name as a link' do
        query = DataMapper::Query.new(repository(:sqlite3), Vehicle,:links => [:factory])
        results = @adapter.read_set(repository(:sqlite3),query)
        results.should have(1).entries
      end

      it 'should accept a string of an association name as a link' do
        query = DataMapper::Query.new(repository(:sqlite3), Vehicle,:links => ['factory'])
        results = @adapter.read_set(repository(:sqlite3),query)
        results.should have(1).entries
      end

      it 'should accept a mixture of items as a set of links' do
        region = DataMapper::Associations::Relationship.new(
          :region,
          :sqlite3,
          'Factory',
          'Region',
          { :child_key => [ :region_id ], :parent_key => [ :id ] }
        )
        query = DataMapper::Query.new(repository(:sqlite3), Vehicle,:links => ['factory',region])
        results = @adapter.read_set(repository(:sqlite3), query)
        results.should have(1).entries
      end

      it 'should only accept a DM::Assoc::Relationship, String & Symbol as a link' do
        lambda{
          DataMapper::Query.new(repository(:sqlite3), Vehicle,:links => [1])
        }.should raise_error(ArgumentError)
      end

      it 'should have a association by the name of the Symbol or String' do
        lambda{
          DataMapper::Query.new(repository(:sqlite3), Vehicle,:links=>['Sailing'])
        }.should raise_error(ArgumentError)

        lambda{
          DataMapper::Query.new(repository(:sqlite3), Vehicle,:links=>[:sailing])
        }.should raise_error(ArgumentError)
      end

      it 'should create an n-level query path' do
        Vehicle.factory.region.model.should == Region
        Vehicle.factory.region.name.property.should == Region.properties(Region.repository.name)[:name]
      end

      it 'should accept a DM::QueryPath as the key to a condition' do
        vehicle = Vehicle.first(Vehicle.factory.region.name => 'North West')
        vehicle.name.should == '10 ton delivery truck'
      end


      it 'should auto generate the link if a DM::Property from a different resource is in the :fields option'
      it 'should create links with composite keys'


      it 'should eager load associations' do
        repository(:sqlite3) do
          vehicle = Vehicle.first(:includes => [Vehicle.factory])
        end
      end

      after do
        @adapter.execute('DROP TABLE "regions"')
        @adapter.execute('DROP TABLE "factories"')
        @adapter.execute('DROP TABLE "vehicles"')
      end
    end   # describe links
  end # DM::Query
end
