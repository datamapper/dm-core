require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

gem 'fastercsv', '>=1.2.3'
require 'fastercsv'

begin
  gem 'do_sqlite3', '=0.9.0'
  require 'do_sqlite3'

  DataMapper.setup(:sqlite3, "sqlite3://#{INTEGRATION_DB_PATH}")

  describe DataMapper::Type do

    before do

      @adapter = repository(:sqlite3).adapter
      @adapter.execute("CREATE TABLE coconuts (id INTEGER PRIMARY KEY, faked TEXT, active INTEGER, note TEXT)")

      module TypeTests
        class Impostor < DataMapper::Type
          primitive String
        end

        class Coconut
          include DataMapper::Resource

          storage_names[:sqlite3] = 'coconuts'

          property :id, Fixnum, :serial => true
          property :faked, Impostor
          property :active, Boolean
          property :note, Text
        end
      end
      
      @active = true
      @note = "This is a note on our ol' guy bob"
    end

    it "should instantiate an object with custom types" do
      coconut = TypeTests::Coconut.new(:faked => 'bob', :active => @active, :note => @note)
      coconut.faked.should == 'bob'
      coconut.active.should be_a_kind_of(TrueClass)
      coconut.note.should be_a_kind_of(String)
    end

    it "should CRUD an object with custom types" do
      repository(:sqlite3) do
        coconut = TypeTests::Coconut.new(:faked => 'bob', :active => @active, :note => @note)
        coconut.save.should be_true
        coconut.id.should_not be_nil

        fred = TypeTests::Coconut[coconut.id]
        fred.faked.should == 'bob'
        fred.active.should be_a_kind_of(TrueClass)
        fred.note.should be_a_kind_of(String)

        fred.note = "Seems like bob is just mockin' around"

        fred.save.should be_true
        
        fred.active = false

        fred.save.should be_true
        
        # Can't call coconut.reload! since coconut.loaded_set isn't setup.
        mac = TypeTests::Coconut[fred.id]
        mac.active.should == false
        mac.note.should == "Seems like bob is just mockin' around"
      end
    end

    after do
      @adapter = repository(:sqlite3).adapter
      @adapter.execute("DROP TABLE coconuts")
    end
  end
rescue LoadError
  warn "integration/type_spec not run! Could not load do_sqlite3."
end
