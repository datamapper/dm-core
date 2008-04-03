require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'
require 'faster_csv'

begin
  require 'do_sqlite3'


  describe DataMapper::Property do
    describe" tracking strategies" do
    
      before do
        class Actor
          include DataMapper::Resource
        
          property :id, Fixnum, :serial => true
          property :name, String, :lock => true
          property :notes, DataMapper::Types::Text, :track => false
          property :age, Fixnum, :track => :set
          property :rating, Fixnum # :track default should be false for immutable types
          property :location, String # :track default should be :get for mutable types
          property :lead, TrueClass, :track => :load
          property :agent, String, :track => :hash # :track only Object#hash value on :load.
            # Potentially faster, but less safe, so use judiciously, when the odds of a hash-collision are low.
        end
      
        @adapter = DataMapper::Repository.adapters[:sqlite3] || DataMapper.setup(:sqlite3, "sqlite3://#{__DIR__}/integration_test.db")
        @adapter.execute <<-EOS.compress_lines
          CREATE TABLE actors (
            id INTEGER PRIMARY KEY,
            name TEXT,
            notes TEXT,
            age INTEGER,
            rating INTEGER,
            location TEXT,
            lead BOOLEAN,
            agent TEXT
          )
        EOS
      end
    
      it "false" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end
    
      it ":load" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end
    
      it ":hash" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end
    
      it ":get" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end
    
      it ":set" do
        pending("Implementation...")
        DataMapper::Resource::DIRTY.should_not be_nil
        bob = Actor.new(:name => 'bob')
        bob.original_attributes.should have_key(:name)
        bob.original_attributes[:name].should == DataMapper::Resource::DIRTY
      end
      
      after do
        @adapter.execute("DROP TABLE actors")
      end
    end
    
    describe "lazy loading" do
      before do
        @adapter = DataMapper::Repository.adapters[:sqlite3] || DataMapper.setup(:sqlite3, "sqlite3://#{__DIR__}/integration_test.db")
        @adapter.execute(<<-EOS.compress_lines) rescue nil
          CREATE TABLE "sail_boats" (
            "id" INTEGER PRIMARY KEY,
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
        repository(:sqlite3).save(SailBoat.new(:id => 1, :notes=>'Note',:trip_report=>'Report',:miles=>23))
        repository(:sqlite3).save(SailBoat.new(:id => 2, :notes=>'Note',:trip_report=>'Report',:miles=>23))
        repository(:sqlite3).save(SailBoat.new(:id => 3, :notes=>'Note',:trip_report=>'Report',:miles=>23))
      end


      it "should lazy load in context" do
        result = repository(:sqlite3).all(SailBoat,{})
        result[0].instance_variables.should_not include('@notes')
        result[0].instance_variables.should_not include('@trip_report')
        result[1].instance_variables.should_not include('@notes')
        result[0].notes.should_not be_nil
        result[1].instance_variables.should include('@notes')
        result[1].instance_variables.should include('@trip_report')
        result[1].instance_variables.should_not include('@miles')

        result = repository(:sqlite3).all(SailBoat,{})
        result[0].instance_variables.should_not include('@trip_report')
        result[0].instance_variables.should_not include('@miles')

        result[1].trip_report.should_not be_nil
        result[2].instance_variables.should include('@miles')
      end

      after do
       @adapter.execute('DROP TABLE "sail_boats"')
      end

    end  

  end
  
rescue LoadError
  warn "integration/property_spec not run! Could not load do_sqlite3."
end
