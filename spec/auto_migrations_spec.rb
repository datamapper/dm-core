require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::AutoMigrations do
  before(:all) do
    DataMapper::Persistable.drop_all_tables!
    DataMapper::Persistable.subclasses.clear
  end

#  before(:each) do
#    DataMapper::Persistable.drop_all_tables!
#  end
#  
#  after(:all) do
#    DataMapper::Persistable.drop_all_tables!
#    DataMapper::Persistable.auto_migrate!
#  end

#  describe DataMapper::Base do
#    it "should auto migrate all" do
#      DataMapper::Base.auto_migrate!
#
#      repository.adapter.schema.database_tables.size.should == Dir[File.dirname(__FILE__) + '/fixtures/*'].size
#    end
#
#    describe "when migrating a descendant" do
#      before do
#	class Descendant < DataMapper::Base
#	  property :one, :string
#	  property :two, :string
#	  property :three, :string
#	end
#      end
#
#      it "should work" do
#	Descendant.auto_migrate!
#
#	repository.table_exists?(Descendant).should be_true
#	repository.column_exists_for_table?(Descendant, :one).should be_true
#	repository.column_exists_for_table?(Descendant, :two).should be_true
#	repository.column_exists_for_table?(Descendant, :three).should be_true
#	repository.adapter.schema.database_tables.size.should == 1
#      end
#
#      after do
#	repository.schema[Descendant].drop!
#      end
#    end
#  end
  
  it "should find all new models" do
    Zoo.auto_migrate!

    repository.table_exists?(Zoo).should be_true
    repository.column_exists_for_table?(Zoo, :id).should be_true
    repository.column_exists_for_table?(Zoo, :name).should be_true
    repository.column_exists_for_table?(Zoo, :notes).should be_true
    repository.column_exists_for_table?(Zoo, :updated_at).should be_true    
    repository.adapter.schema.database_tables.size.should == 1
  end
  
  it "should find all changed models"
  it "should find all unmapped tables"

  describe Zoo, "with auto-migrations" do
    it "should allow auto migration" do
      Zoo.should respond_to("auto_migrate!")
    end
  end

  describe "when migrating a new model" do
    it "should allow creation of new tables for new models"
    it "should allow renaming of unmapped tables for new models"
    it "should create columns for the model's properties"
  end

  describe "when migrating a changed model" do
    it "should find all new properties"
    it "should allow creation of new columns for new properties"
    it "should allow an unmapped column to be renamed for a new property"
    it "should find all unmapped columns"
    it "should allow removal of any or all unmapped columns"
  end

  describe "when migrating an unmapped table" do
    it "should allow the table to be dropped"
  end

  describe "after migrating" do
    it "should store migration decisions to allow the migration to be replicated"
  end

  after(:all) do
    DataMapper::Persistable.subclasses.clear
    DataMapper::Persistable.subclasses.concat INITIAL_CLASSES
    
    DataMapper::Persistable.auto_migrate!

    load_database
  end
end
