require File.join(File.dirname(__FILE__), 'spec_helper')

# * you have some crazy finder options... ie: Zoo, :name => 'bob', :include => :exhibits
# 
# * you want to turn this into SQL.
# 
# * you want to execute this SQL...
# 
# * you want to load objects from the results, which means you have to know what columns in the results map to what objects
# 
# * some values in the results will have no corresponding objects, theyll be indicators of other behaviour that should take place
#   ie: the values for a m:n join table will tell you how to bind the associated objects together, or...
#     the :type column will tell you what type to instantiate    
#
#
# So... the Query class should basically take the options from step 1, give you the SQL in step 2,
# allow you to handle step 3, and expose types/result-set mappings to load objects by for step 4.
# step 5 should be handled in the DataObjectAdapter
describe DataMapper::Query do
  
  it "should generate the correct queries for the given options" do
    query = DataMapper::Query.new(repository(:mock).adapter, Zoo, :name => 'bob')
    query.to_sql.should == "SELECT `id`, `name`, `updated_at` FROM `zoos` WHERE (`name` = ?)"
    query.parameters.should == ['bob']
    
    query = DataMapper::Query.new(repository(:mock).adapter, Animal, :name => 'bob')
    query.to_sql.should == "SELECT `id`, `name`, `nice` FROM `animals` WHERE (`name` = ?)"
    query.parameters.should == ['bob']
    
    query = DataMapper::Query.new(repository(:mock).adapter, Project)
    query.to_sql.should == "SELECT `id`, `title`, `description`, `deleted_at` FROM `projects` WHERE (`deleted_at` IS NULL OR `deleted_at` > NOW())"
    query.parameters.should be_empty
  end
  
  it "should use the include option for lazily-loaded columns" do
    query = DataMapper::Query.new(repository(:mock).adapter, Zoo, :include => :notes)
    query.to_sql.should == "SELECT `id`, `name`, `notes`, `updated_at` FROM `zoos`"
    query.parameters.should be_empty
  end
  
  it "should generate the correct join query" do
    query = DataMapper::Query.new(repository(:mock).adapter, Zoo, :include => [:exhibits])
    query.to_sql.should == <<-EOS.compress_lines
      SELECT `zoos`.`id`, `zoos`.`name`, `zoos`.`updated_at`, `exhibits`.`id`, `exhibits`.`name`, `exhibits`.`zoo_id`
      FROM `zoos`
      JOIN `exhibits` ON `exhibits`.`zoo_id` = `zoos`.`id`
    EOS
    
    query = DataMapper::Query.new(repository(:mock).adapter, Zoo, :include => [:exhibits], :name => ['bob', 'sam'])
    query.to_sql.should == <<-EOS.compress_lines
      SELECT `zoos`.`id`, `zoos`.`name`, `zoos`.`updated_at`, `exhibits`.`id`, `exhibits`.`name`, `exhibits`.`zoo_id`
      FROM `zoos`
      JOIN `exhibits` ON `exhibits`.`zoo_id` = `zoos`.`id`
      WHERE (`zoos`.`name` IN ?)
    EOS
    query.parameters.should == [['bob', 'sam']]
  end
  
  it "should be forgiving with options that require Arrays" do
    
    query = DataMapper::Query.new(repository(:mock).adapter, Zoo, :conditions => ["`name` = ?", 'bob'])
    query.to_sql.should == "SELECT `id`, `name`, `updated_at` FROM `zoos` WHERE (`name` = ?)"
    query.parameters.should == ['bob']
    
    query = DataMapper::Query.new(repository(:mock).adapter, Zoo, :conditions => "`name` = 'bob'")
    query.to_sql.should == "SELECT `id`, `name`, `updated_at` FROM `zoos` WHERE (`name` = 'bob')"
    query.parameters.should be_empty
    
    query = DataMapper::Query.new(repository(:mock).adapter, Zoo, :include => :exhibits)
    query.to_sql.should == <<-EOS.compress_lines
      SELECT `zoos`.`id`, `zoos`.`name`, `zoos`.`updated_at`, `exhibits`.`id`, `exhibits`.`name`, `exhibits`.`zoo_id`
      FROM `zoos`
      JOIN `exhibits` ON `exhibits`.`zoo_id` = `zoos`.`id`
    EOS
  end
  
end
