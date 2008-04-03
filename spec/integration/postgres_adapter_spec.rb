require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require __DIR__.parent.parent + 'lib/data_mapper'

begin
  require 'do_postgres'

  DataMapper.setup(:postgres, "postgres://postgres@localhost/dm_core_test")

  describe DataMapper::Adapters::PostgresAdapter do
    before do
      @uri = URI.parse("postgres://postgres@localhost/dm_core_test")
    end

    it 'should override the path when the option is passed' do
      pending
      adapter = DataMapper::Adapters::PostgresAdapter.new(:mock, @uri, { :path => '/dm_core_test2' })
      adapter.instance_variable_get("@uri").should == URI.parse("postgres://postgres@localhost/dm_core_test2")
    end

    it 'should accept the uri when no overrides exist' do
      adapter = DataMapper::Adapters::PostgresAdapter.new(:mock, @uri)
      adapter.instance_variable_get("@uri").should == @uri
    end
  end

  describe DataMapper::Adapters::DataObjectsAdapter do

    describe "reading & writing a database" do

      before do
        @adapter = repository(:postgres).adapter
        @adapter.execute("CREATE TABLE users (id SERIAL NOT NULL, name TEXT)")
        @adapter.execute("INSERT INTO users (name) VALUES ('Paul')")
      end

      it 'should be able to #execute an arbitrary query' do
        result = @adapter.execute("INSERT INTO users (name) VALUES ('Sam')")

        result.affected_rows.should == 1
      end

      it 'should be able to #query' do
        result = @adapter.query("SELECT * FROM users")

        result.should be_kind_of(Array)
        row = result.first
        row.should be_kind_of(Struct)
        row.members.should == %w{id name}

        row.id.should == 1
        row.name.should == 'Paul'
      end

      it 'should return an empty array if #query found no rows' do
        @adapter.execute("DELETE FROM users")

        result = nil
        lambda { result = @adapter.query("SELECT * FROM users") }.should_not raise_error

        result.should be_kind_of(Array)
        result.size.should == 0
      end

      after do
        @adapter.execute('DROP TABLE "users"')
      end
    end

    describe "CRUD for serial Key" do
      before do
        class VideoGame
          include DataMapper::Resource

          property :id, Fixnum, :serial => true
          property :name, String
        end

        @adapter = repository(:postgres).adapter
        @adapter.execute('CREATE TABLE "video_games" ("id" SERIAL NOT NULL, "name" VARCHAR(50))') rescue nil
      end

      it 'should be able to create a record' do
        game = VideoGame.new(:name => 'System Shock')
        repository(:postgres).save(game)

        game.should_not be_a_new_record
        game.should_not be_dirty

        @adapter.query('SELECT "id" FROM "video_games" WHERE "name" = ?', game.name).first.should == game.id
        @adapter.execute('DELETE FROM "video_games" WHERE "id" = ? RETURNING id', game.id).to_i.should == 1
      end

      it 'should be able to read a record' do
        name = 'Wing Commander: Privateer'
        id = @adapter.execute('INSERT INTO "video_games" ("name") VALUES (?) RETURNING id', name).insert_id

        game = repository(:postgres).get(VideoGame, [id])
        game.name.should == name
        game.should_not be_dirty
        game.should_not be_a_new_record

        @adapter.execute('DELETE FROM "video_games" WHERE "name" = ?', name)
      end

      it 'should be able to update a record' do
        name = 'Resistance: Fall of Mon'
        id = @adapter.execute('INSERT INTO "video_games" ("name") VALUES (?) RETURNING id', name).insert_id

        game = repository(:postgres).get(VideoGame, [id])
        game.name = game.name.sub(/Mon/, 'Man')

        game.should_not be_a_new_record
        game.should be_dirty

        repository(:postgres).save(game)

        game.should_not be_dirty

        clone = repository(:postgres).get(VideoGame, [id])

        clone.name.should == game.name

        @adapter.execute('DELETE FROM "video_games" WHERE "id" = ?', id)
      end

      it 'should be able to delete a record' do
        name = 'Zelda'
        id = @adapter.execute('INSERT INTO "video_games" ("name") VALUES (?) RETURNING id', name).insert_id

        game = repository(:postgres).get(VideoGame, [id])
        game.name.should == name

        repository(:postgres).destroy(game).should be_true
        game.should be_a_new_record
        game.should be_dirty
      end

      it 'should respond to Resource#get' do

        name = 'Contra'
        id = @adapter.execute('INSERT INTO "video_games" ("name") VALUES (?) RETURNING id', name).insert_id

        puts id.inspect

        contra = repository(:postgres) { VideoGame.get(id) }

        puts contra.id.inspect

        contra.should_not be_nil
        contra.should_not be_dirty
        contra.should_not be_a_new_record
        contra.id.should == id
      end

      after do
        @adapter.execute('DROP TABLE "video_games"')
      end
    end

    describe "CRUD for Composite Key" do
      before do
        class BankCustomer
          include DataMapper::Resource

          property :bank, String, :key => true
          property :account_number, String, :key => true
          property :name, String
        end

        @adapter = repository(:postgres).adapter
        @adapter.execute('CREATE TABLE "bank_customers" ("bank" VARCHAR(50), "account_number" VARCHAR(50), "name" VARCHAR(50))') rescue nil
      end

      it 'should be able to create a record' do
        customer = BankCustomer.new(:bank => 'Community Bank', :acount_number => '123456', :name => 'David Hasselhoff')
        repository(:postgres).save(customer)

        customer.should_not be_a_new_record
        customer.should_not be_dirty

        row = @adapter.query('SELECT "bank", "account_number" FROM "bank_customers" WHERE "name" = ?', customer.name).first
        row.bank.should == customer.bank
        row.account_number.should == customer.account_number
      end

      it 'should be able to read a record' do
        bank, account_number, name = 'Chase', '4321', 'Super Wonderful'
        @adapter.execute('INSERT INTO "bank_customers" ("bank", "account_number", "name") VALUES (?, ?, ?)', bank, account_number, name)

        repository(:postgres).get(BankCustomer, [bank, account_number]).name.should == name

        @adapter.execute('DELETE FROM "bank_customers" WHERE "bank" = ? AND "account_number" = ?', bank, account_number)
      end

      it 'should be able to update a record' do
        bank, account_number, name = 'Wells Fargo', '00101001', 'Spider Pig'
        @adapter.execute('INSERT INTO "bank_customers" ("bank", "account_number", "name") VALUES (?, ?, ?)', bank, account_number, name)

        customer = repository(:postgres).get(BankCustomer, [bank, account_number])
        customer.name = 'Bat-Pig'

        customer.should_not be_a_new_record
        customer.should be_dirty

        repository(:postgres).save(customer)

        customer.should_not be_dirty

        clone = repository(:postgres).get(BankCustomer, [bank, account_number])

        clone.name.should == customer.name

        @adapter.execute('DELETE FROM "bank_customers" WHERE "bank" = ? AND "account_number" = ?', bank, account_number)
      end

      it 'should be able to delete a record' do
        bank, account_number, name = 'Megacorp', 'ABC', 'Flash Gordon'
        @adapter.execute('INSERT INTO "bank_customers" ("bank", "account_number", "name") VALUES (?, ?, ?)', bank, account_number, name)

        customer = repository(:postgres).get(BankCustomer, [bank, account_number])
        customer.name.should == name

        repository(:postgres).destroy(customer).should be_true
        customer.should be_a_new_record
        customer.should be_dirty
      end

      it 'should respond to Resource#get' do
        bank, account_number, name = 'Conchords', '1100101', 'Robo Boogie'
        @adapter.execute('INSERT INTO "bank_customers" ("bank", "account_number", "name") VALUES (?, ?, ?)', bank, account_number, name)

        robots = repository(:postgres) { BankCustomer.get(bank, account_number) }

        robots.should_not be_nil
        robots.should_not be_dirty
        robots.should_not be_a_new_record
        robots.bank.should == bank
        robots.account_number.should == account_number
      end

      after do
        @adapter.execute('DROP TABLE "bank_customers"')
      end
    end

    describe "Ordering a Query" do
      before do

        @adapter = repository(:postgres).adapter
        @adapter.execute(<<-EOS.compress_lines) rescue nil
          CREATE TABLE "sail_boats" (
            "id" SERIAL NOT NULL,
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
              properties(repository.name).detect(name)
            end
          end
        end

        repository(:postgres).save(SailBoat.new(:id => 1, :name => "A", :port => "C"))
        repository(:postgres).save(SailBoat.new(:id => 2, :name => "B", :port => "B"))
        repository(:postgres).save(SailBoat.new(:id => 3, :name => "C", :port => "A"))
      end

      it "should order results" do
        result = repository(:postgres).all(SailBoat,{:order => [
            DataMapper::Query::Direction.new(SailBoat.property_by_name(:name), :asc)
        ]})
        result[0].id.should == 1

        result = repository(:postgres).all(SailBoat,{:order => [
            DataMapper::Query::Direction.new(SailBoat.property_by_name(:port), :asc)
        ]})
        result[0].id.should == 3

        result = repository(:postgres).all(SailBoat,{:order => [
            DataMapper::Query::Direction.new(SailBoat.property_by_name(:name), :asc),
            DataMapper::Query::Direction.new(SailBoat.property_by_name(:port), :asc)
        ]})
        result[0].id.should == 1


        result = repository(:postgres).all(SailBoat,{:order => [
            SailBoat.property_by_name(:name),
            DataMapper::Query::Direction.new(SailBoat.property_by_name(:port), :asc)
        ]})
        result[0].id.should == 1
      end

      after do
       @adapter.execute('DROP TABLE "sail_boats"')
      end

    end

    describe "Lazy Loaded Properties" do

      before do

        @adapter = repository(:postgres).adapter
        @adapter.execute(<<-EOS.compress_lines) rescue nil
          CREATE TABLE "sail_boats" (
            "id" SERIAL NOT NULL,
            "notes" VARCHAR(50),
            "trip_report" VARCHAR(50),
            "miles" INTEGER
          )
        EOS

        class SailBoat
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :notes, String, :lazy => [:notes]
          property :trip_report, String, :lazy => [:notes,:trip]
          property :miles, Fixnum, :lazy => [:trip]

          class << self
            def property_by_name(name)
              properties(repository.name).detect(name)
            end
          end
        end

        repository(:postgres).save(SailBoat.new(:id => 1, :notes=>'Note',:trip_report=>'Report',:miles=>23))
        repository(:postgres).save(SailBoat.new(:id => 2, :notes=>'Note',:trip_report=>'Report',:miles=>23))
        repository(:postgres).save(SailBoat.new(:id => 3, :notes=>'Note',:trip_report=>'Report',:miles=>23))
      end


      it "should lazy load" do
        result = repository(:postgres).all(SailBoat,{})
        result[0].instance_variables.should_not include('@notes')
        result[0].instance_variables.should_not include('@trip_report')
        result[1].instance_variables.should_not include('@notes')
        result[0].notes.should_not be_nil
        result[1].instance_variables.should include('@notes')
        result[1].instance_variables.should include('@trip_report')
        result[1].instance_variables.should_not include('@miles')

        result = repository(:postgres).all(SailBoat,{})
        result[0].instance_variables.should_not include('@trip_report')
        result[0].instance_variables.should_not include('@miles')

        result[1].trip_report.should_not be_nil
        result[2].instance_variables.should include('@miles')
      end

      after do
       @adapter.execute('DROP TABLE "sail_boats"')
      end

    end

    describe "finders" do

      before do

        class SerialFinderSpec
          include DataMapper::Resource

          property :id, Fixnum, :serial => true
          property :sample, String
        end

        @adapter = repository(:postgres).adapter

        @adapter.execute(<<-EOS.compress_lines)
          CREATE TABLE "serial_finder_specs" (
            "id" SERIAL NOT NULL,
            "sample" VARCHAR(50)
          )
        EOS

        # Why do we keep testing with Repository instead of the models directly?
        # Just because we're trying to target the code we're actualling testing
        # as much as possible.
        setup_repository = repository(:postgres)
        100.times do
          setup_repository.save(SerialFinderSpec.new(:sample => rand.to_s))
        end
      end

      it "should return all available rows" do
        repository(:postgres).all(SerialFinderSpec, {}).should have(100).entries
      end

      it "should allow limit and offset" do
        repository(:postgres).all(SerialFinderSpec, { :limit => 50 }).should have(50).entries

        repository(:postgres).all(SerialFinderSpec, { :limit => 20, :offset => 40 }).map(&:id).should ==
          repository(:postgres).all(SerialFinderSpec, {})[40...60].map(&:id)
      end

      it "should lazy-load missing attributes" do
        sfs = repository(:postgres).all(SerialFinderSpec, { :fields => [:id], :limit => 1 }).first
        sfs.should be_a_kind_of(SerialFinderSpec)
        sfs.should_not be_a_new_record

        sfs.instance_variables.should_not include('@sample')
        sfs.sample.should_not be_nil
      end

      it "should translate an Array to an IN clause" do
        ids = repository(:postgres).all(SerialFinderSpec, { :limit => 10 }).map(&:id)
        results = repository(:postgres).all(SerialFinderSpec, { :id => ids })

        results.size.should == 10
        results.map(&:id).should == ids
      end

      after do
        @adapter.execute('DROP TABLE "serial_finder_specs"')
      end

    end

    describe "many_to_one associations" do
      before do
        class Engine
          include DataMapper::Resource

          property :id, Fixnum, :serial => true
          property :name, String
        end

        @adapter = repository(:postgres).adapter

        @adapter.execute(<<-EOS.compress_lines)
          CREATE TABLE "engines" (
            "id" SERIAL NOT NULL,
            "name" VARCHAR(50)
          )
        EOS

        @adapter.execute('INSERT INTO "engines" ("id", "name") values (?, ?)', 1, 'engine1')
        @adapter.execute('INSERT INTO "engines" ("id", "name") values (?, ?)', 2, 'engine2')

        class Yard
          include DataMapper::Resource

          property :id, Fixnum, :serial => true
          property :name, String

          many_to_one :engine, :repository_name => :postgres
        end

        @adapter.execute(<<-EOS.compress_lines)
          CREATE TABLE "yards" (
            "id" SERIAL NOT NULL,
            "name" VARCHAR(50),
            "engine_id" INTEGER
          )
        EOS

        @adapter.execute('INSERT INTO "yards" ("id", "name", "engine_id") values (?, ?, ?)', 1, 'yard1', 1)
      end

      it "should materialize without the parent"

      it 'should allow substituting the parent' do
        y = repository(:postgres).all(Yard, :id => 1).first
        e = repository(:postgres).all(Engine, :id => 2).first

        y.engine = e
        repository(:postgres).save(y)

        y = repository(:postgres).all(Yard, :id => 1).first
        y[:engine_id].should == 2
      end

      it "#many_to_one" do
        yard = Yard.new
        yard.should respond_to(:engine)
        yard.should respond_to(:engine=)
      end

      it "should load the associated instance" do
        y = repository(:postgres).all(Yard, :id => 1).first
        y.engine.should_not be_nil
        y.engine.id.should == 1
        y.engine.name.should == "engine1"
      end

      it 'should save the association key in the child' do
        e = repository(:postgres).all(Engine, :id => 2).first
        repository(:postgres).save(Yard.new(:id => 2, :name => 'yard2', :engine => e))

        repository(:postgres).all(Yard, :id => 2).first[:engine_id].should == 2
      end

      it 'should save the parent upon saving of child' do
        e = Engine.new(:id => 10, :name => "engine10")
        y = Yard.new(:id => 10, :name => "Yard10", :engine => e)
        repository(:postgres).save(y)

        y[:engine_id].should == 10
        repository(:postgres).all(Engine, :id => 10).first.should_not be_nil
      end

      after do
        @adapter.execute('DROP TABLE "yards"')
        @adapter.execute('DROP TABLE "engines"')
      end
    end

    describe "one_to_many associations" do
      before do
        class Host
          include DataMapper::Resource

          property :id, Fixnum, :serial => true
          property :name, String

          one_to_many :slices, :repository_name => :postgres
        end

        @adapter = repository(:postgres).adapter

        @adapter.execute(<<-EOS.compress_lines)
          CREATE TABLE "hosts" (
            "id" SERIAL NOT NULL,
            "name" VARCHAR(50)
          )
        EOS

        @adapter.execute('INSERT INTO "hosts" ("id", "name") values (?, ?)', 1, 'host1')
        @adapter.execute('INSERT INTO "hosts" ("id", "name") values (?, ?)', 2, 'host2')

        class Slice
          include DataMapper::Resource

          property :id, Fixnum, :serial => true
          property :name, String

          many_to_one :host, :repository_name => :postgres
        end

        @adapter.execute(<<-EOS.compress_lines)
          CREATE TABLE "slices" (
            "id" SERIAL NOT NULL,
            "name" VARCHAR(50),
            "host_id" INTEGER
          )
        EOS

        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, ?)', 1, 'slice1', 1)
        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, ?)', 2, 'slice2', 1)
      end

      it "#one_to_many" do
        h = Host.new
        h.should respond_to(:slices)
      end

      it "should allow removal of a child through a loaded association" do
        h = repository(:postgres).all(Host, :id => 1).first
        s = h.slices.first

        h.slices.delete(s)
        h.slices.size.should == 1

        s = repository(:postgres).first(Slice, :id => s.id)
        s.host.should be_nil
        s[:host_id].should be_nil
      end

      it "should load the associated instances" do
        h = repository(:postgres).all(Host, :id => 1).first
        h.slices.should_not be_nil
        h.slices.size.should == 2
        h.slices.first.id.should == 1
        h.slices.last.id.should == 2
      end

      it "should add and save the associated instance" do
        h = repository(:postgres).all(Host, :id => 1).first
        h.slices << Slice.new(:id => 3, :name => 'slice3')

        s = repository(:postgres).all(Slice, :id => 3).first
        s.host.id.should == 1
      end

      it "should not save the associated instance if the parent is not saved" do
        h = Host.new(:id => 10, :name => "host10")
        h.slices << Slice.new(:id => 10, :name => 'slice10')

        repository(:postgres).all(Slice, :id => 10).first.should be_nil
      end

      it "should save the associated instance upon saving of parent" do
        h = Host.new(:id => 10, :name => "host10")
        h.slices << Slice.new(:id => 10, :name => 'slice10')
        repository(:postgres).save(h)

        s = repository(:postgres).all(Slice, :id => 10).first
        s.should_not be_nil
        s.host.should_not be_nil
        s.host.id.should == 10
      end

      after do
        @adapter.execute('DROP TABLE "slices"')
        @adapter.execute('DROP TABLE "hosts"')
      end
    end
  end
rescue LoadError
  warn "PostgreSQL specs not run! Could not load do_postgres."
end
