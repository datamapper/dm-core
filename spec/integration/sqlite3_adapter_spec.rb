require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

begin
  gem 'do_sqlite3', '=0.9.0'
  require 'do_sqlite3'

  DataMapper.setup(:sqlite3, "sqlite3://#{INTEGRATION_DB_PATH}")

  describe DataMapper::Adapters::DataObjectsAdapter do

    describe "handling transactions" do
      before :all do
        @adapter = repository(:sqlite3).adapter
        @adapter.execute('DROP TABLE IF EXISTS "sputniks"')
        @adapter.execute('CREATE TABLE "sputniks" (id serial, name text)')
      end

      before :each do
        @transaction = DataMapper::Adapters::Transaction.new(@adapter)
      end

      it "should rollback changes when #rollback_transaction is called" do
        @transaction.commit do |transaction|
          @adapter.execute("INSERT INTO sputniks (name) VALUES ('my pretty sputnik')")
          transaction.rollback
        end
        @adapter.query("SELECT * FROM sputniks WHERE name = 'my pretty sputnik'").empty?.should == true
      end
      it "should commit changes when #commit_transaction is called" do
        @transaction.commit do
          @adapter.execute("INSERT INTO sputniks (name) VALUES ('my pretty sputnik')")
        end
        @adapter.query("SELECT * FROM sputniks WHERE name = 'my pretty sputnik'").size.should == 1
      end
    end

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

      it 'should respond to Resource#get' do
        name = 'Contra'
        id = @adapter.execute('INSERT INTO "video_games" ("name") VALUES (?)', name).insert_id

        contra = repository(:sqlite3) { VideoGame.get(id) }

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

      it 'should respond to Resource#get' do
        bank, account_number, name = 'Conchords', '1100101', 'Robo Boogie'
        @adapter.execute('INSERT INTO "bank_customers" ("bank", "account_number", "name") VALUES (?, ?, ?)', bank, account_number, name)

        robots = repository(:sqlite3) { BankCustomer.get(bank, account_number) }

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
  end
rescue LoadError => e
  describe 'do_sqlite3' do
    it 'should be required' do
      fail "SQLite3 integration specs not run! Could not load do_sqlite3: #{e}"
    end
  end
end
