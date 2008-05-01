require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

class Book
  include DataMapper::Resource

  property :id,             Fixnum, :key => true
  property :isbn,           String
  property :published,      Date
  property :available,      TrueClass
  property :description,    DM::Text
  property :classification, Class
  property :price,          BigDecimal
  property :in_print,       Float
  property :inventoried,    DateTime
  property :pdf,            Object
end

describe 'common type map', :shared => true do

  it 'should create the published column as a DATE' do
    @table_set.find { |c| c[@col_identifier] == 'published' }.type.upcase.should == 'DATE'
  end

  it 'should create the pdf column as TEXT' do
    @table_set.find { |c| c[@col_identifier] == 'pdf' }.type.upcase.should == 'TEXT'
  end
end

begin
  require 'do_sqlite3'

  DataMapper.setup(:sqlite3, "sqlite3://#{INTEGRATION_DB_PATH}")

  describe DataMapper::AutoMigrations, :sqlite3 do
    before :all do
      @adapter = repository(:sqlite3).adapter

      DataMapper::AutoMigrator.models.clear
    end

    after :all do
      DataMapper::AutoMigrator.models.clear
    end

    describe 'auto_migrate!' do
      it_should_behave_like 'common type map'

      before :all do
        Book.auto_migrate!(:sqlite3)
        @table_set = @adapter.query('PRAGMA table_info("books");')
        @col_identifier = 'name'
      end

      it 'should create the id column as an INTEGER' do
        @table_set.find { |c| c[@col_identifier] == 'id' }.type.upcase.should == 'INTEGER'
      end

      it 'should create the isbn column as a VARCHAR(50)' do
        @table_set.find { |c| c[@col_identifier] == 'isbn' }.type.upcase.should == 'VARCHAR(50)'
      end

      it 'should create the available column as a BOOLEAN' do
        @table_set.find { |c| c[@col_identifier] == 'available' }.type.upcase.should == 'BOOLEAN'
      end

      it 'should create the description column as TEXT' do
        @table_set.find { |c| c[@col_identifier] == 'description' }.type.upcase.should == 'TEXT'
      end

      it 'should create the classification column as a VARCHAR(50)' do
        @table_set.find { |c| c[@col_identifier] == 'classification' }.type.upcase.should == 'VARCHAR(50)'
      end

      it 'should create the price column as a DECIMAL' do
        @table_set.find { |c| c[@col_identifier] == 'price' }.type.upcase.should == 'DECIMAL'
      end

      it 'should create the in_print column as a FLOAT ' do
        @table_set.find { |c| c[@col_identifier] == 'in_print' }.type.upcase.should == 'FLOAT'
      end

      it 'should create the inventoried column as a DATETIME' do
        @table_set.find { |c| c[@col_identifier] == 'inventoried' }.type.upcase.should == 'DATETIME'
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

  DataMapper.setup(:mysql, 'mysql://localhost/dm_integration_test')

  describe DataMapper::AutoMigrations, :mysql do
    before :all do
      @adapter = repository(:mysql).adapter

      DataMapper::AutoMigrator.models.clear
    end

    after :all do
      DataMapper::AutoMigrator.models.clear
    end

    describe 'auto_migrate!' do
      it_should_behave_like 'common type map'

      before :all do
        Book.auto_migrate!(:mysql)
        @table_set = @adapter.query('describe `books`;')
        @col_identifier = 'field'
      end

      it 'should create the id column as an INT(11)' do
        @table_set.find { |c| c[@col_identifier] == 'id' }.type.upcase.should == 'INT(11)'
      end

      it 'should create the isbn column as a VARCHAR(50)' do
        @table_set.find { |c| c[@col_identifier] == 'isbn' }.type.upcase.should == 'VARCHAR(50)'
      end

      it 'should create the available column as a TINYINT(1)' do
        @table_set.find { |c| c[@col_identifier] == 'available' }.type.upcase.should == 'TINYINT(1)'
      end

      it 'should create the description column as TEXT' do
        @table_set.find { |c| c[@col_identifier] == 'description' }.type.upcase.should == 'TEXT'
      end

      it 'should create the classification column as a VARCHAR(50)' do
        @table_set.find { |c| c[@col_identifier] == 'classification' }.type.upcase.should == 'VARCHAR(50)'
      end

      it 'should create the price column as a DECIMAL(10,0)' do
        @table_set.find { |c| c[@col_identifier] == 'price' }.type.upcase.should == 'DECIMAL(10,0)'
      end

      it 'should create the in_print column as a FLOAT ' do
        @table_set.find { |c| c[@col_identifier] == 'in_print' }.type.upcase.should == 'FLOAT'
      end

      it 'should create the inventoried column as a DATETIME' do
        @table_set.find { |c| c[@col_identifier] == 'inventoried' }.type.upcase.should == 'DATETIME'
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

  DataMapper.setup(:postgres, 'postgres://postgres@localhost/dm_core_test')

  describe DataMapper::AutoMigrations, :postgres do
    before :all do
      @adapter = repository(:postgres).adapter

      DataMapper::AutoMigrator.models.clear
    end

    after :all do
      DataMapper::AutoMigrator.models.clear
    end

    describe 'auto_migrate!' do
      it_should_behave_like 'common type map'

      before :all do
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

      it 'should create the isbn column as a VARCHAR' do
        @table_set.find { |c| c[@col_identifier] == 'isbn' }.type.upcase.should == 'VARCHAR'
      end

      it 'should create the id column as an INT4' do
        @table_set.find { |c| c[@col_identifier] == 'id' }.type.upcase.should == 'INT4'
      end

      it 'should create the available column as a BOOL' do
        @table_set.find { |c| c[@col_identifier] == 'available' }.type.upcase.should == 'BOOL'
      end

      it 'should create the description column as TEXT' do
        @table_set.find { |c| c[@col_identifier] == 'description' }.type.upcase.should == 'TEXT'
      end

      it 'should create the classification column as a VARCHAR' do
        @table_set.find { |c| c[@col_identifier] == 'classification' }.type.upcase.should == 'VARCHAR'
      end

      it 'should create the price column as a NUMERIC' do
        @table_set.find { |c| c[@col_identifier] == 'price' }.type.upcase.should == 'NUMERIC'
      end

      it 'should create the in_print column as a FLOAT8' do
        @table_set.find { |c| c[@col_identifier] == 'in_print' }.type.upcase.should == 'FLOAT8'
      end

      it 'should create the inventoried column as a TIMESTAMP' do
        @table_set.find { |c| c[@col_identifier] == 'inventoried' }.type.upcase.should == 'TIMESTAMP'
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