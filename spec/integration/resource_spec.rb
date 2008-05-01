require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

begin
  gem 'do_sqlite3', '=0.9.0'
  require 'do_sqlite3'

  DataMapper.setup(:sqlite3, "sqlite3://#{INTEGRATION_DB_PATH}") unless DataMapper::Repository.adapters[:sqlite3]

  describe "DataMapper::Resource" do
    describe "inheritance" do
      before(:all) do
        class Father
          include DataMapper::Resource
          property :id, Fixnum, :serial => true
          property :name, String
          
          property :type, Class, :default => lambda { |r,p| p.model }
        end
        
        class Son < Father
          property :favourite, Boolean, :default => false
        end
        
        Son.auto_migrate!(:sqlite3)
        
        repository(:sqlite3) do
          Father.create!(:name => 'Bob')
          Son.create!(:name => 'Fred', :favourite => true)
          Son.create!(:name => 'Barney')
          Father.create!(:name => 'Johnson')
        end
      end
      
      it "should select appropriate types" do
        repository(:sqlite3) do
          fathers = Father.all
          fathers.should have(4).entries
          
          fathers.each do |father|
            father.class.name.should == father.type.name
          end
          
          Father.first(:name => 'Bob').should be_a_kind_of(Father)
          Son.first(:name => 'Fred').should be_a_kind_of(Son)
          Son.first(:name => 'Barney').should be_a_kind_of(Son)
          Father.first(:name => 'Johnson').should be_a_kind_of(Father)
        end
      end
    end
  end
rescue LoadError
  warn "integration/repository_spec not run! Could not load do_sqlite3."
end
