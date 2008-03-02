require File.dirname(__FILE__) + "/spec_helper"

# Only run these specs when the ADAPTER env-variable is set to 'postgresql'
# You will probably need to set the DATABASE and USERNAME vars as well.
if ENV['ADAPTER'] == 'postgresql'

  describe DataMapper::Adapters::PostgresqlAdapter::Mappings::Column do
    before(:all) do
      @mappings = DataMapper::Adapters::PostgresqlAdapter::Mappings
      @table    = @mappings::Table.new(repository(:mock).adapter, "Zebu")      
    end
    
    it "should be able to set check-constraints on columns" do
      column   = @mappings::Column.new(repository(:mock).adapter, @table, :age,
                   :integer, 1, { :check => "age > 18"})
      column.to_long_form.should match(/CHECK \(age > 18\)/)
    end
    
    it "should not set varchar length if none is specified" do
      column   = @mappings::Column.new(repository(:mock).adapter, @table,
                   :varchar_len_test, :string, 1, { })
      column.size.should == nil
      column.to_long_form.should match(/.varchar_len_test. varchar/)
    end
    
    it "should set varchar length when it is specified" do
      column   = @mappings::Column.new(repository(:mock).adapter, @table,
                   :varchar_len_test, :string, 1, { :length => 100 })
      column.size.should == 100
      column.to_long_form.should match(/.varchar_len_test. varchar\(100\)/)
    end
    
    it "should accept :size as alternative to :length" do
      column   = @mappings::Column.new(repository(:mock).adapter, @table,
                   :varchar_len_test, :string, 1, { :size => 100 })
      column.size.should == 100
      column.to_long_form.should match(/.varchar_len_test. varchar\(100\)/)
    end
    
    it "should have size of nil when length of integer is specified" do
      column   = @mappings::Column.new(repository(:mock).adapter, @table,
                   :integer_len_test, :integer, 1, { :length => 1 })
      column.size.should == nil
      column.to_long_form.should match(/.integer_len_test./)
    end
    
    it "should have size of nil when length of integer is not specified, overriding the default" do
      column   = @mappings::Column.new(repository(:mock).adapter, @table,
                   :integer_len_test, :integer, 1)
      column.size.should == nil
      column.to_long_form.should match(/.integer_len_test./)
    end
  end

  describe DataMapper::Adapters::PostgresqlAdapter::Mappings::Table do
    
    before(:all) do
      class Cage #< DataMapper::Base # please do not remove this
        include DataMapper::Base

        set_table_name "cages"
        property :name, :string
      end
  
      class CageInSchema #< DataMapper::Base # please do not remove this
        include DataMapper::Base

        set_table_name "my_schema.cages"
        property :name, :string
      end
    end
    
    it "should return a quoted table name for a simple table" do
      table_sql = repository.adapter.table(Cage).to_sql
      table_sql.should == "\"cages\""
    end
  
    it "should return a quoted schema and table name for a table which specifies a schema" do
      table_sql = repository.adapter.table(CageInSchema).to_sql
      table_sql.should == "\"my_schema\".\"cages\""
    end

    it "should search only the specified schema if qualified" do
      repository.save(Cage)
      repository.adapter.table(CageInSchema).exists?.should == false
      repository.save(CageInSchema)
      repository.adapter.table(CageInSchema).exists?.should == true
    end
    
    after do
      repository.adapter.execute("DROP SCHEMA my_schema CASCADE") rescue nil
    end
    
  end

end
