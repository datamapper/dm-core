require File.dirname(__FILE__) + "/spec_helper"
require File.dirname(__FILE__) + "/../lib/data_mapper/migration"

class MigrationUser
  include DataMapper::Persistable
  
  property :name, :string
  property :login, :string
  
end

def check_schema
  case ENV['ADAPTER']
  when 'postgresql'
    result = repository.query("
    SELECT table_name, column_name FROM information_schema.columns WHERE table_name = 'migration_users'
    ").join(", ")
    result.blank? ? nil : result
  when 'mysql'
    begin
      repository.query("SHOW CREATE TABLE migration_users")[0]["create table"]
    rescue Exception => e
      raise e unless e.message.match(/Table.*doesn\'t exist/)
    end
  else
    repository.query("
    SELECT sql FROM
       (SELECT * FROM sqlite_master UNION ALL
        SELECT * FROM sqlite_temp_master)
    WHERE name = 'migration_users'
    ORDER BY substr(type,2,1), name
    ")[0]
  end
end

describe DataMapper::Migration do
  
  class AddUsers < DataMapper::Migration
    def self.up
      table :migration_users do # sees that the users table does not exist and so creates the table
        add :name, :string
        add :login, :string
      end
    end

    def self.down
      table.drop :migration_users
    end
  end

  class AddPasswordToUsers < DataMapper::Migration
    def self.up
      table :migration_users do
        add :password, :string
      end
    end

    def self.down
      table :migration_users do
        remove :password
      end
    end
  end

  class RenameLoginOnUsers < DataMapper::Migration
    def self.up
      table :migration_users do
        rename :login, :username
      end
    end

    def self.down
      table :migration_users do
        rename :username, :login
      end
    end
  end
  
  class AlterLoginOnUsers < DataMapper::Migration
    def self.up
      table :migration_users do
        alter :login, :text, :nullable => false, :default => "username"
      end
    end
    
    def self.down
      table :migration_users do
        alter :login, :string
      end
    end
  end
  
  it "should migrate up creating a table with its columns" do
    AddUsers.migrate(:up)
    repository.table_exists?(MigrationUser).should be_true
    check_schema.should match(/migration_users/)
    check_schema.should match(/name|login/)
    user = MigrationUser.new(:name => "test", :login => "username")
    user.save.should be_true
    MigrationUser.first.should == user
  end
  
  it "should migrate down deleting the created table" do
    AddUsers.migrate(:down)
    check_schema.should be_nil
    repository.table_exists?(MigrationUser).should == false
  end
  
  it "should migrate up altering a table to add a column" do
    AddUsers.migrate(:up)
    AddPasswordToUsers.migrate(:up)
    table = repository.table(MigrationUser)
    table[:password].should_not be_nil
  end
  
  it "should migrate down altering a table to remove a column" do
    check_schema.should match(/password/)
    AddPasswordToUsers.migrate(:down)
    check_schema.should_not match(/password/)
    table = repository.table(MigrationUser)
    table[:password].should be_nil
    AddUsers.migrate(:down)
  end
  
  it "should migrate up renaming a column" do
    AddUsers.migrate(:up)
    user = MigrationUser.create(:name => "Sam", :login => "sammy")
    RenameLoginOnUsers.migrate(:up)
    class MigrationUser
      property :username, :string
    end
    check_schema.should match(/username/)
    check_schema.should_not match(/login/)
    MigrationUser.first.username.should == user.login
  end
  
  it "should migrate down renaming a column" do
    user = MigrationUser.first
    RenameLoginOnUsers.migrate(:down)
    check_schema.should_not match(/username/)
    check_schema.should match(/login/)
    MigrationUser.first.login.should == user.username
    AddUsers.migrate(:down)
  end
  
  it "should migrate up altering a column" do
    AddUsers.migrate(:up)
    AlterLoginOnUsers.migrate(:up)
    column = repository.table(MigrationUser)[:login]
    column.type.should == :text
    column.nullable?.should be_false
    column.default.should == "username"
  end
  
  it "should migrate down altering a column" do
    AlterLoginOnUsers.migrate(:down)
    column = repository.table(MigrationUser)[:login]
    column.type.should == :string
    column.nullable?.should be_true
    column.default.should be_nil
    AddUsers.migrate(:down)
  end
end

describe "DataMapper::Migration [RAILS]" do
  class RailsAddUsers < DataMapper::Migration
    def self.up
      create_table :migration_users do |t|
        t.column :name, :string
        t.column :login, :string
      end
    end
  
    def self.down
      drop_table :migration_users
    end
  end

  class RailsAddPasswordToUsers < DataMapper::Migration
    def self.up
      add_column :migration_users, :password, :string
    end
  
    def self.down
      remove_column :migration_users, :password
    end
  end
  
  class RailsRenameLoginOnUsers < DataMapper::Migration
    def self.up
      rename_column :migration_users, :login, :username
    end

    def self.down
      rename_column :migration_users, :username, :login
    end
  end
  
  class RailsAlterLoginOnUsers < DataMapper::Migration
    def self.up
      change_column :migration_users, :login, :text, :nullable => false, :default => "username"
    end
    
    def self.down
      change_column :migration_users, :login, :string
    end
  end
  
  it "should migrate up creating a table with its columns" do
    RailsAddUsers.migrate(:up)
    repository.table_exists?(MigrationUser).should be_true
    check_schema.should match(/migration_users/)
    check_schema.should match(/name|login/)
  end
  
  it "should migrate down deleting the created table" do
    RailsAddUsers.migrate(:down)
    repository.table_exists?(MigrationUser).should be_false
    check_schema.should be_nil
  end
  
  it "should migrate up altering a table to add a column" do
    RailsAddUsers.migrate(:up)
    RailsAddPasswordToUsers.migrate(:up)
    check_schema.should match(/password/)
  end
  
  it "should migrate down altering a table to remove a column" do
    RailsAddPasswordToUsers.migrate(:down)
    check_schema.should_not match(/password/)
    table = repository.table(MigrationUser)
    table[:password].should be_nil
    RailsAddUsers.migrate(:down)
  end
  
  it "should migrate up renaming a column" do
    RailsAddUsers.migrate(:up)
    RailsRenameLoginOnUsers.migrate(:up)
    check_schema.should match(/username/)
    check_schema.should_not match(/login/)
  end
  
  it "should migrate down renaming a column" do
    RailsRenameLoginOnUsers.migrate(:down)
    check_schema.should match(/login/)
    check_schema.should_not match(/username/)
    RailsAddUsers.migrate(:down)
  end
  
  it "should migrate up altering a column" do
    AddUsers.migrate(:up)
    RailsAlterLoginOnUsers.migrate(:up)
    column = repository.table(MigrationUser)[:login]
    column.type.should == :text
    column.nullable?.should be_false
    column.default.should == "username"
  end
  
  it "should migrate down altering a column" do
    RailsAlterLoginOnUsers.migrate(:down)
    column = repository.table(MigrationUser)[:login]
    column.type.should == :string
    column.nullable?.should be_true
    column.default.should be_nil
    AddUsers.migrate(:down)
  end
end
