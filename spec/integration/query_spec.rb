require File.join(File.dirname(__FILE__), '..', 'spec_helper')

begin
  require 'do_sqlite3'

  DataMapper.setup(:sqlite3, "sqlite3://#{INTEGRATION_DB_PATH}")
  DataMapper.setup(:mock, "mock:///mock.db")

  describe DataMapper::Query do
    describe 'when ordering' do
      before do
        @adapter = repository(:sqlite3).adapter
        @adapter.execute(<<-EOS.compress_lines) rescue nil
          CREATE TABLE "sail_boats" (
            "id" INTEGER PRIMARY KEY,
            "name" VARCHAR(50),
            "port" VARCHAR(50)
          )
        EOS

        class SailBoat
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :name, String
          property :port, String

          class << self
            def property_by_name(name)
              properties(repository.name)[name]
            end
          end
        end

        repository(:sqlite3).save(SailBoat.new(:id => 1, :name => "A", :port => "C"))
        repository(:sqlite3).save(SailBoat.new(:id => 2, :name => "B", :port => "B"))
        repository(:sqlite3).save(SailBoat.new(:id => 3, :name => "C", :port => "A"))
      end

      it "should order results" do
        result = repository(:sqlite3).all(SailBoat,{:order => [
              DataMapper::Query::Direction.new(SailBoat.property_by_name(:name), :asc)
            ]})
        result[0].id.should == 1

        result = repository(:sqlite3).all(SailBoat,{:order => [
              DataMapper::Query::Direction.new(SailBoat.property_by_name(:port), :asc)
            ]})
        result[0].id.should == 3

        result = repository(:sqlite3).all(SailBoat,{:order => [
              DataMapper::Query::Direction.new(SailBoat.property_by_name(:name), :asc),
              DataMapper::Query::Direction.new(SailBoat.property_by_name(:port), :asc)
            ]})
        result[0].id.should == 1

        result = repository(:sqlite3).all(SailBoat,{:order => [
              SailBoat.property_by_name(:name),
              DataMapper::Query::Direction.new(SailBoat.property_by_name(:port), :asc)
            ]})
        result[0].id.should == 1
      end

      after do
        @adapter.execute('DROP TABLE "sail_boats"')
      end
    end

    describe 'when sub-selecting' do
      before do
        @adapter = repository(:sqlite3).adapter

        @adapter.execute(<<-EOS.compress_lines) rescue nil
          CREATE TABLE "sail_boats" (
            "id" INTEGER PRIMARY KEY,
            "name" VARCHAR(50),
            "port" VARCHAR(50),
            "captain" VARCHAR(50)
          )
        EOS
        @adapter.execute(<<-EOS.compress_lines) rescue nil
          CREATE TABLE "permissions" (
            "id" INTEGER PRIMARY KEY,
            "user_id" INTEGER,
            "resource_id" INTEGER,
            "resource_type" VARCHAR(50),
            "token" VARCHAR(50)
          )
        EOS

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

        repository(:sqlite3).save(SailBoat.new(:id => 1, :name => "Fantasy I", :port => "Cape Town", :captain => 'Joe'))
        repository(:sqlite3).save(SailBoat.new(:id => 2, :name => "Royal Flush II", :port => "Cape Town", :captain => 'James'))
        repository(:sqlite3).save(SailBoat.new(:id => 3, :name => "Infringer III", :port => "Cape Town", :captain => 'Jason'))

        #User 1 permission -- read boat 1 & 2
        repository(:sqlite3).save(Permission.new(:id => 1, :user_id => 1, :resource_id => 1, :resource_type => 'SailBoat', :token => 'READ'))
        repository(:sqlite3).save(Permission.new(:id => 2, :user_id => 1, :resource_id => 2, :resource_type => 'SailBoat', :token => 'READ'))

        #User 2 permission  -- read boat 2 & 3
        repository(:sqlite3).save(Permission.new(:id => 3, :user_id => 2, :resource_id => 2, :resource_type => 'SailBoat', :token => 'READ'))
        repository(:sqlite3).save(Permission.new(:id => 4, :user_id => 2, :resource_id => 3, :resource_type => 'SailBoat', :token => 'READ'))
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
        @adapter.execute(<<-EOS.compress_lines) rescue nil
          CREATE TABLE "regions" (
            "id" INTEGER PRIMARY KEY,
            "name" VARCHAR(50)
          )
        EOS
        @adapter.execute(<<-EOS.compress_lines) rescue nil
          CREATE TABLE "factories" (
            "id" INTEGER PRIMARY KEY,
            "region_id" INTEGER,
            "name" VARCHAR(50)
          )
        EOS
        @adapter.execute(<<-EOS.compress_lines) rescue nil
          CREATE TABLE "vehicles" (
            "id" INTEGER PRIMARY KEY,
            "factory_id" INTEGER,
            "name" VARCHAR(50)
          )
        EOS
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
          {},
          :sqlite3,
          'Vehicle',
          [ :factory_id ],
          'Factory',
          [ :id ]
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
          {},
          :sqlite3,
          'Factory',
          [ :region_id ],
          'Region',
          [ :id ]
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
rescue LoadError
  warn "integration/query_spec not run! Could not load do_sqlite3."
end
