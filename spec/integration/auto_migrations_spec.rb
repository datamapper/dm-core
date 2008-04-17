require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require ROOT_DIR + 'lib/data_mapper'

class Book
  include DataMapper::Resource
  
  property :id,             Fixnum
  property :isbn,           String
  property :published,      Date
  property :available,      TrueClass
  property :description,    DataMapper::Types::Text
  property :classification, Class
  property :price,          BigDecimal
  property :in_print,       Float
  property :inventoried,    DateTime
  property :pdf,            Object
end

describe "common type map", :shared => true do
  
  it "should create the published column as a datetime" do
    @table_set.any? {|c| c[@col_identifier] == "published" && c.type == "date"}.should be_true
  end
  
  it "should create the pdf column as text" do
    @table_set.any? {|c| c[@col_identifier] == "pdf" && c.type == "text"}.should be_true
  end
end

begin
  require 'do_sqlite3'

  DataMapper.setup(:sqlite3, "sqlite3://#{INTEGRATION_DB_PATH}")
  
  describe DataMapper::AutoMigrations, :sqlite3 do
    before(:each) do
      @adapter = repository(:sqlite3).adapter
      
      DataMapper::AutoMigrator.models.clear
    end
    
    after(:each) do
      DataMapper::AutoMigrator.models.clear
    end
    
    describe "auto_migrate!" do
      it_should_behave_like "common type map"
      
      before(:each) do
        Book.auto_migrate!(:sqlite3)
        @table_set = @adapter.query("PRAGMA table_info('books');")
        @col_identifier = "name"
      end
      
      it "should create the id column as an int" do
        @table_set.any? {|c| c[@col_identifier] == "id" && c.type == "int"}.should be_true
      end
      
      it "should create the isbn column as a varchar" do
        @table_set.any? {|c| c[@col_identifier] == "isbn" && c.type == "varchar"}.should be_true
      end
      
      it "should create the available column as a boolean" do
        @table_set.any? {|c| c[@col_identifier] == "available" && c.type == "boolean"}.should be_true
      end
      
      it "should create the description column as text" do
        @table_set.any? {|c| c[@col_identifier] == "description" && c.type == "text"}.should be_true
      end
      
      it "should create the classification column as a varchar" do
        @table_set.any? {|c| c[@col_identifier] == "classification" && c.type == "varchar"}.should be_true
      end
      
      it "should create the price column as a decimal" do
        @table_set.any? {|c| c[@col_identifier] == "price" && c.type == "decimal"}.should be_true
      end
      
      it "should create the in_print column as a float " do
        @table_set.any? {|c| c[@col_identifier] == "in_print" && c.type == "float"}.should be_true
      end
      
      it "should create the inventoried column as a datetime" do
        @table_set.any? {|c| c[@col_identifier] == "inventoried" && c.type == "datetime"}.should be_true
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

begin
  require 'do_mysql'

  DataMapper.setup(:mysql, "mysql://localhost/dm_integration_test")
  
  describe DataMapper::AutoMigrations, :mysql do
    before(:each) do
      @adapter = repository(:mysql).adapter
      
      DataMapper::AutoMigrator.models.clear
    end
    
    after(:each) do
      DataMapper::AutoMigrator.models.clear
    end
    
    describe "auto_migrate!" do
      it_should_behave_like "common type map"
      
      before(:each) do
        Book.auto_migrate!(:mysql)
        @table_set = @adapter.query("describe `books`;")
        @col_identifier = "field"
      end
      
      it "should create the id column as an int(11)" do
        @table_set.any? {|c| c[@col_identifier] == "id" && c.type == "int(11)"}.should be_true
      end
      
      it "should create the isbn column as a varchar(100)" do
        @table_set.any? {|c| c[@col_identifier] == "isbn" && c.type == "varchar(100)"}.should be_true
      end
      
      it "should create the available column as a tinyint(1)" do
        @table_set.any? {|c| c[@col_identifier] == "available" && c.type == "tinyint(1)"}.should be_true
      end
      
      it "should create the description column as varchar(100)" do
        @table_set.any? {|c| c[@col_identifier] == "description" && c.type == "varchar(100)"}.should be_true
      end
      
      it "should create the classification column as a varchar(100)" do
        @table_set.any? {|c| c[@col_identifier] == "classification" && c.type == "varchar(100)"}.should be_true
      end
      
      it "should create the price column as a decimal(10,0)" do
        @table_set.any? {|c| c[@col_identifier] == "price" && c.type == "decimal(10,0)"}.should be_true
      end
      
      it "should create the in_print column as a float " do
        @table_set.any? {|c| c[@col_identifier] == "in_print" && c.type == "float"}.should be_true
      end
      
      it "should create the inventoried column as a datetime" do
        @table_set.any? {|c| c[@col_identifier] == "inventoried" && c.type == "datetime"}.should be_true
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

begin
  require 'do_postgres'

  DataMapper.setup(:postgres, "postgres://postgres@localhost/dm_core_test")
  
  describe DataMapper::AutoMigrations, :postgres do
    before(:each) do
      @adapter = repository(:postgres).adapter
      
      DataMapper::AutoMigrator.models.clear
    end
    
    after(:each) do
      DataMapper::AutoMigrator.models.clear
    end
    
    describe "auto_migrate!" do
      it_should_behave_like "common type map"
      
      before(:each) do
        Book.auto_migrate!(:postgres)
        @table_set = @adapter.query %{
          SELECT
            -- Field
            pg_attribute.attname AS "Field",
            -- Type
            CASE pg_type.typname
              WHEN 'varchar' THEN 'varchar'
              ELSE pg_type.typname
            END AS "Type",
            -- Null
            CASE WHEN pg_attribute.attnotnull THEN ''
              ELSE 'YES'
            END AS "Null",
            -- Default
            CASE pg_type.typname
              WHEN 'varchar' THEN substring(pg_attrdef.adsrc from E'^\\'(.*)\\'.*$')
              ELSE pg_attrdef.adsrc
            END AS "Default"
          FROM pg_class
            INNER JOIN pg_attribute
              ON (pg_class.oid=pg_attribute.attrelid)
            INNER JOIN pg_type
              ON (pg_attribute.atttypid=pg_type.oid)
            LEFT JOIN pg_attrdef
              ON (pg_class.oid=pg_attrdef.adrelid AND pg_attribute.attnum=pg_attrdef.adnum)
          WHERE pg_class.relname='books' AND pg_attribute.attnum>=1 AND NOT pg_attribute.attisdropped
          ORDER BY pg_attribute.attnum;
        }
        @col_identifier = "field"
      end
      
      it "should create the isbn column as a varchar" do
        @table_set.any? {|c| c[@col_identifier] == "isbn" && c.type == "varchar"}.should be_true
      end
      
      it "should create the id column as an int4" do
        @table_set.any? {|c| c[@col_identifier] == "id" && c.type == "int4"}.should be_true
      end
      
      it "should create the available column as a bool" do
        @table_set.any? {|c| c[@col_identifier] == "available" && c.type == "bool"}.should be_true
      end
      
      it "should create the description column as text" do
        @table_set.any? {|c| c[@col_identifier] == "description" && c.type == "text"}.should be_true
      end
      
      it "should create the classification column as a varchar" do
        @table_set.any? {|c| c[@col_identifier] == "classification" && c.type == "varchar"}.should be_true
      end
      
      it "should create the price column as a numeric" do
        @table_set.any? {|c| c[@col_identifier] == "price" && c.type == "numeric"}.should be_true
      end
      
      it "should create the in_print column as a float8" do
        @table_set.any? {|c| c[@col_identifier] == "in_print" && c.type == "float8"}.should be_true
      end
      
      it "should create the inventoried column as a timestamp" do
        @table_set.any? {|c| c[@col_identifier] == "inventoried" && c.type == "timestamp"}.should be_true
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