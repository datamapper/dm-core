require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::Sql::Mappings::Table do
  it "should return all columns from the database" do
    table = repository.adapter.schema.database_tables.detect{|table| table.name == "zoos"}
    columns = table.database_columns
    columns.size.should == repository.schema[Zoo].columns.size
    columns.each { |column| column.should be_a_kind_of( DataMapper::Adapters::Sql::Mappings::Column ) }
  end
  
  it "should return the default for a column from the database" do
    table = repository.adapter.schema.database_tables.detect{|table| table.name == "animals"}
    columns = table.database_columns
    
    column1 = columns.detect{|column| column.name == :name }
    column1.default.should == "No Name"
    
    column2 = columns.detect{|column| column.name == :nice }
    column2.default.should == nil
  end
  
  it "should return the nullability for a column from the database" do
    table = repository.adapter.schema.database_tables.detect{|table| table.name == "animals"}
    columns = table.database_columns
    
    column1 = columns.detect{|column| column.name == :id }
    column1.nullable?.should be_false
    
    column2 = columns.detect{|column| column.name == :nice }
    column2.nullable?.should be_true
  end
  
  it "should create sql for composite unique indexes" do
    class Cage #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable
      
      property :name, :string
      property :cage_id, :integer
      
      index [:name, :cage_id], :unique => true
    end
    
    index_sql = repository.adapter.table(Cage).to_create_composite_index_sql
    index_sql[0].should match(/CREATE UNIQUE INDEX cages_name_cage_id_index/)
  end
  
  it "should create sql for composite indexes" do
    class Lion #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      property :name, :string
      property :tamer_id, :integer
      
      index [:name, :tamer_id]
    end
    
    index_sql = repository.adapter.table(Lion).to_create_composite_index_sql
    index_sql[0].should match(/CREATE INDEX lions_name_tamer_id_index/)
  end
  
  it "should create sql for multiple composite indexes" do
    class Course #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      property :code, :string
      property :name, :string
      property :description, :text
      property :department_id, :integer
      property :professor_id, :integer
      
      index [:code, :name], :unique => true
      index [:department_id, :professor_id], :unique => true
    end
    
    index_sql = repository.adapter.table(Course).to_create_composite_index_sql
    index_sql[0].should match(/CREATE UNIQUE INDEX courses_code_name_index/)
    index_sql[1].should match(/CREATE UNIQUE INDEX courses_department_id_professor_id_index/)    
  end
end
