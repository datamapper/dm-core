require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require __DIR__.parent.parent + 'lib/data_mapper'

DataMapper.setup(:sqlite3, "sqlite3://#{__DIR__}/integration_test.db")

describe DataMapper::Adapters::Sqlite3Adapter do
  before do
    @uri = URI.parse("sqlite3:///test.db")
  end

  it 'should override the path when the option is passed' do
    adapter = DataMapper::Adapters::Sqlite3Adapter.new(:mock, @uri, { :path => '/test2.db' })
    adapter.instance_variable_get("@uri").should == URI.parse("sqlite3:///test2.db")
  end

  it 'should accept the uri when no overrides exist' do
    adapter = DataMapper::Adapters::Sqlite3Adapter.new(:mock, @uri)
    adapter.instance_variable_get("@uri").should == @uri
  end
end

describe DataMapper::Adapters::DataObjectsAdapter do

  describe "reading & writing a database" do

    before do
      @adapter = repository(:sqlite3).adapter
      @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
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

      @adapter = repository(:sqlite3).adapter
      @adapter.execute('CREATE TABLE "video_games" ("id" INTEGER PRIMARY KEY, "name" VARCHAR(50))') rescue nil
    end

    it 'should be able to create a record' do
      game = VideoGame.new(:name => 'System Shock')
      repository(:sqlite3).save(game)

      game.should_not be_a_new_record
      game.should_not be_dirty

      @adapter.query('SELECT "id" FROM "video_games" WHERE "name" = ?', game.name).first.should == game.id
      @adapter.execute('DELETE FROM "video_games" WHERE "id" = ?', game.id).to_i.should == 1
    end

    it 'should be able to read a record' do
      name = 'Wing Commander: Privateer'
      id = @adapter.execute('INSERT INTO "video_games" ("name") VALUES (?)', name).insert_id

      game = repository(:sqlite3).get(VideoGame, [id])
      game.name.should == name
      game.should_not be_dirty
      game.should_not be_a_new_record

      @adapter.execute('DELETE FROM "video_games" WHERE "name" = ?', name)
    end

    it 'should be able to update a record' do
      name = 'Resistance: Fall of Mon'
      id = @adapter.execute('INSERT INTO "video_games" ("name") VALUES (?)', name).insert_id

      game = repository(:sqlite3).get(VideoGame, [id])
      game.name = game.name.sub(/Mon/, 'Man')

      game.should_not be_a_new_record
      game.should be_dirty

      repository(:sqlite3).save(game)

      game.should_not be_dirty

      clone = repository(:sqlite3).get(VideoGame, [id])

      clone.name.should == game.name

      @adapter.execute('DELETE FROM "video_games" WHERE "id" = ?', id)
    end

    it 'should be able to delete a record' do
      name = 'Zelda'
      id = @adapter.execute('INSERT INTO "video_games" ("name") VALUES (?)', name).insert_id

      game = repository(:sqlite3).get(VideoGame, [id])
      game.name.should == name

      repository(:sqlite3).destroy(game).should be_true
      game.should be_a_new_record
      game.should be_dirty
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

      @adapter = repository(:sqlite3).adapter
      @adapter.execute('CREATE TABLE "bank_customers" ("bank" VARCHAR(50), "account_number" VARCHAR(50), "name" VARCHAR(50))') rescue nil
    end

    it 'should be able to create a record' do
      customer = BankCustomer.new(:bank => 'Community Bank', :acount_number => '123456', :name => 'David Hasselhoff')
      repository(:sqlite3).save(customer)

      customer.should_not be_a_new_record
      customer.should_not be_dirty

      row = @adapter.query('SELECT "bank", "account_number" FROM "bank_customers" WHERE "name" = ?', customer.name).first
      row.bank.should == customer.bank
      row.account_number.should == customer.account_number
    end

    it 'should be able to read a record' do
      bank, account_number, name = 'Chase', '4321', 'Super Wonderful'
      @adapter.execute('INSERT INTO "bank_customers" ("bank", "account_number", "name") VALUES (?, ?, ?)', bank, account_number, name)

      repository(:sqlite3).get(BankCustomer, [bank, account_number]).name.should == name

      @adapter.execute('DELETE FROM "bank_customers" WHERE "bank" = ? AND "account_number" = ?', bank, account_number)
    end

    it 'should be able to update a record' do
      bank, account_number, name = 'Wells Fargo', '00101001', 'Spider Pig'
      @adapter.execute('INSERT INTO "bank_customers" ("bank", "account_number", "name") VALUES (?, ?, ?)', bank, account_number, name)

      customer = repository(:sqlite3).get(BankCustomer, [bank, account_number])
      customer.name = 'Bat-Pig'

      customer.should_not be_a_new_record
      customer.should be_dirty

      repository(:sqlite3).save(customer)

      customer.should_not be_dirty

      clone = repository(:sqlite3).get(BankCustomer, [bank, account_number])

      clone.name.should == customer.name

      @adapter.execute('DELETE FROM "bank_customers" WHERE "bank" = ? AND "account_number" = ?', bank, account_number)
    end

    it 'should be able to delete a record' do
      bank, account_number, name = 'Megacorp', 'ABC', 'Flash Gordon'
      @adapter.execute('INSERT INTO "bank_customers" ("bank", "account_number", "name") VALUES (?, ?, ?)', bank, account_number, name)

      customer = repository(:sqlite3).get(BankCustomer, [bank, account_number])
      customer.name.should == name

      repository(:sqlite3).destroy(customer).should be_true
      customer.should be_a_new_record
      customer.should be_dirty
    end

    after do
      @adapter.execute('DROP TABLE "bank_customers"')
    end
  end

  describe "query" do

    before do

      @adapter = repository(:sqlite3).adapter
      @adapter.execute(<<-EOS.compress_lines) rescue nil
        CREATE TABLE "sail_boats" (
          "id" INTEGER PRIMARY KEY,
          "name" VARCHAR(50),
          "port" VARCHAR(50),
          "notes" VARCHAR(50),
          "trip_report" VARCHAR(50),
          "miles" INTEGER
        )
      EOS

      class SailBoat
        include DataMapper::Resource
        property :id, Fixnum, :serial => true
        property :name, String
        property :port, String
        property :notes, String, :lazy => [:notes]
        property :trip_report, String, :lazy => [:notes,:trip]
        property :miles, Fixnum, :lazy => [:trip]

        class << self
          def property_by_name(name)
            properties(repository.name).detect do |property|
              property.name == name
            end
          end
        end
      end

      repository(:sqlite3).save(SailBoat.new(:id => 1, :name => "A", :port => "C",:notes=>'Note',:trip_report=>'Report',:miles=>23))
      repository(:sqlite3).save(SailBoat.new(:id => 2, :name => "B", :port => "B",:notes=>'Note',:trip_report=>'Report',:miles=>23))
      repository(:sqlite3).save(SailBoat.new(:id => 3, :name => "C", :port => "A",:notes=>'Note',:trip_report=>'Report',:miles=>23))
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

#    it "should lazy load" do
#      result = repository(:sqlite3).all(SailBoat,{})
#      result[0].instance_variables.should_not include('@notes')
#      result[0].instance_variables.should_not include('@trip_report')
#      result[1].instance_variables.should_not include('@notes')
#      result[0].notes.should_not be_nil
#      result[1].instance_variables.should include('@notes')
#      result[1].instance_variables.should include('@trip_report')
#      result[1].instance_variables.should_not include('@miles')

#      result = repository(:sqlite3).all(SailBoat,{})
#      result[0].instance_variables.should_not include('@trip_report')
#      result[0].instance_variables.should_not include('@miles')

#      result[1].trip_report.should_not be_nil
#      result[2].instance_variables.should include('@miles')

#    end

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

      @adapter = repository(:sqlite3).adapter

      @adapter.execute(<<-EOS.compress_lines)
        CREATE TABLE "serial_finder_specs" (
          "id" INTEGER PRIMARY KEY,
          "sample" VARCHAR(50)
        )
      EOS

      # Why do we keep testing with Repository instead of the models directly?
      # Just because we're trying to target the code we're actualling testing
      # as much as possible.
      setup_repository = repository(:sqlite3)
      100.times do
        setup_repository.save(SerialFinderSpec.new(:sample => rand.to_s))
      end
    end

    it "should return all available rows" do
      repository(:sqlite3).all(SerialFinderSpec, {}).should have(100).entries
    end

    it "should allow limit and offset" do
      repository(:sqlite3).all(SerialFinderSpec, { :limit => 50 }).should have(50).entries

      repository(:sqlite3).all(SerialFinderSpec, { :limit => 20, :offset => 40 }).map(&:id).should ==
        repository(:sqlite3).all(SerialFinderSpec, {})[40...60].map(&:id)
    end

    it "should lazy-load missing attributes" do
      sfs = repository(:sqlite3).all(SerialFinderSpec, { :fields => [:id], :limit => 1 }).first
      sfs.should be_a_kind_of(SerialFinderSpec)
      sfs.should_not be_a_new_record

      sfs.instance_variables.should_not include('@sample')
      sfs.sample.should_not be_nil
    end

    it "should translate an Array to an IN clause" do
      ids = repository(:sqlite3).all(SerialFinderSpec, { :limit => 10 }).map(&:id)
      results = repository(:sqlite3).all(SerialFinderSpec, { :id => ids })

      results.size.should == 10
      results.map(&:id).should == ids
    end

    after do
      @adapter.execute('DROP TABLE "serial_finder_specs"')
    end

  end

  describe "associations" do
    before do
      class Engine
        include DataMapper::Resource

        property :id, Fixnum, :key => true
        property :name, String
      end

      @adapter = repository(:sqlite3).adapter

      @adapter.execute(<<-EOS.compress_lines)
        CREATE TABLE "engines" (
          "id" INTEGER PRIMARY KEY,
          "name" VARCHAR(50)
        )
      EOS

      @adapter.execute('INSERT INTO "engines" ("id", "name") values (?, ?)', 1, 'engine1')
      @adapter.execute('INSERT INTO "engines" ("id", "name") values (?, ?)', 2, 'engine2')

      class Yard
        include DataMapper::Resource

        property :id, Fixnum, :key => true
        property :name, String

        belongs_to :engine
      end

      @adapter.execute(<<-EOS.compress_lines)
        CREATE TABLE "yards" (
          "id" INTEGER PRIMARY KEY,
          "name" VARCHAR(50),
          "engine_id" INTEGER
        )
      EOS

      @adapter.execute('INSERT INTO "yards" ("id", "name", "engine_id") values (?, ?, ?)', 1, 'yard1', 1)
    end

    it "#belongs_to" do
      yard = Yard.new
      yard.should respond_to(:engine)
      yard.should respond_to(:engine=)
    end

    it "should load the associated instance" do
      y = repository(:sqlite3).all(Yard, :id => 1).first
      y.engine.should_not be_nil
      y.engine.id.should == 1
      y.engine.name.should == "engine1"
    end

    it 'should save the association key in the child' do
      e = repository(:sqlite3).all(Engine, :id => 2).first
      repository(:sqlite3).save(Yard.new(:id => 2, :name => 'yard2', :engine => e))

      repository(:sqlite3).all(Yard, :id => 2).first.engine.id.should == 2
    end

    after do
      @adapter.execute('DROP TABLE "yards"')
      @adapter.execute('DROP TABLE "engines"')
    end
  end
end
