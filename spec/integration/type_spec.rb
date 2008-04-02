require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'
require 'faster_csv'

DataMapper.setup(:sqlite3, "sqlite3://#{__DIR__}/integration_test.db") unless DataMapper::Repository.adapters[:sqlite3]

describe DataMapper::Type do

  before do
    
    @adapter = repository(:sqlite3).adapter
    @adapter.execute("CREATE TABLE coconuts (id INTEGER PRIMARY KEY, faked TEXT, document TEXT)")
    
    module TypeTests
      class Csv < DataMapper::Type
        primitive String
        size 65535
        lazy true
      
        def self.load(value)
          case value
          when String then FasterCSV.parse(value)
          when Array then value
          else nil
          end
        end
        
        def self.dump(value)
          case value
          when Array then
            FasterCSV.generate do |csv|
              value.each { |row| csv << row }
            end
          when String then value
          else nil
          end  
        end
      end
      
      class Impostor < DataMapper::Type
        primitive String
      end
      
      class Coconut
        include DataMapper::Resource
        
        resource_names[:sqlite3] = 'coconuts'
        
        property :id, Fixnum, :serial => true
        property :faked, Impostor
        property :document, Csv
      end
    end
    
    @document = <<-EOS.margin
      NAME, RATING, CONVENIENCE
      Freebird's, 3, 3
      Whataburger, 1, 5
      Jimmy John's, 3, 4
      Mignon, 5, 2
      Fuzi Yao's, 5, 1
      Blue Goose, 5, 1 
    EOS
  end
  
  it "should instantiate an object with custom types" do
    coconut = TypeTests::Coconut.new(:faked => 'bob', :document => @document)
    coconut.faked.should == 'bob'
    coconut.document.should be_a_kind_of(Array)
  end
  
  it "should CRUD an object with custom types" do
    repository(:sqlite3) do
      coconut = TypeTests::Coconut.new(:faked => 'bob', :document => @document)
      coconut.save.should be_true
      coconut.id.should_not be_nil
    
      fred = TypeTests::Coconut[coconut.id]
      fred.faked.should == 'bob'
      fred.document.should be_a_kind_of(Array)

      texadelphia = ["Texadelphia", "5", "3"]
      
      # Figure out how to track these... possibly proxies? :-p
      document = fred.document.dup
      document << texadelphia
      fred.document = document
      
      fred.save.should be_true
      
      # Can't call coconut.reload! since coconut.loaded_set isn't setup.
      mac = TypeTests::Coconut[fred.id]
      mac.document.last.should == texadelphia
    end
  end
  
  after do
    @adapter = repository(:sqlite3).adapter
    @adapter.execute("DROP TABLE coconuts")
  end
end
