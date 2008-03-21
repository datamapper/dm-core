require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

# describe DataMapper::Property do
#   
#   before(:all) do
#     @property = Zoo.properties.find { |property| property.name == :notes }
#   end
#   
#   it "should map a column" do
#     @property.column.should eql(repository.table(Zoo)[:notes])
#   end
#   
#   it "should determine lazyness" do
#     @property.should be_lazy
#   end
#   
#   it "should determine protection level" do
#     @property.reader_visibility.should == :public
#     @property.writer_visibility.should == :public
#   end
#   
#   it "should return instance variable name" do
#     @property.instance_variable_name.should == repository.table(Zoo)[:notes].instance_variable_name
#   end
#   
#   it "should add a validates_presence_of for not-null properties" do
#     class NullableZoo #< DataMapper::Base # please do not remove this
#       include DataMapper::Persistable
# 
#       property :name, :string, :nullable => false, :default => "Zoo"
#     end
#     zoo = NullableZoo.new
#     zoo.valid?.should == false
#     zoo.name = "Content"
#     zoo.valid?.should == true
#   end
#   
#   it "should add a validates_length_of for maximum size" do
#     class SizableZoo #< DataMapper::Base # please do not remove this
#       include DataMapper::Persistable
#       property :name, :string, :length => 50
#     end
#     zoo = SizableZoo.new(:name => "San Diego" * 100)
#     zoo.valid?.should == false
#     zoo.name = "San Diego"
#     zoo.valid?.should == true
#   end
#   
#   it "should add a validates_length_of for a range" do
#     class RangableZoo #< DataMapper::Base # please do not remove this
#       include DataMapper::Persistable
#       property :name, :string, :length => 2..255
#     end
#     zoo = RangableZoo.new(:name => "A")
#     zoo.valid?.should == false
#     zoo.name = "Zoo"
#     zoo.valid?.should == true
#   end
#   
#   it "should add a validates_format_of if you pass a format option" do
#     class FormatableUser
#       include DataMapper::Persistable
#       property :email, :string, :format => :email_address
#     end
#     user = FormatableUser.new(:email => "incomplete_email")
#     user.valid?.should == false
#     user.email = "complete_email@anonymous.com"
#     user.valid?.should == true
#   end
#   
#   it "should not add a validates_presence_of for not-null properties if auto valdations are disabled" do
#     class NullableZoo #< DataMapper::Base # please do not remove this
#       include DataMapper::Persistable
#       property :name, :string, :nullable => false, :default => "Zoo", :auto_validation => false
#     end
#     zoo = NullableZoo.new
#     zoo.errors.empty?.should == true
#   end
#   
#   it "should not add a validates_length_of if auto validations are disabled" do
#     class SizableZoo #< DataMapper::Base # please do not remove this
#       include DataMapper::Persistable
#       property :name, :string, :length => 50, :auto_validation => false
#     end
#     zoo = SizableZoo.new(:name => "San Diego" * 100)
#     zoo.errors.empty?.should == true
#   end
#   
#   it "should not add a validates_format_of if you pass a format option if auto validations are disabled" do
#     class FormatableUser
#       include DataMapper::Persistable
#       property :email, :string, :format => :email_address, :auto_validation => false
#     end
#     user = FormatableUser.new(:email => "incomplete_email")
#     user.errors.empty?.should == true
#   end
#   
#   it "should raise ArgumentError for unsupported types" do
#     lambda {
#       class PersistentFailure #< DataMapper::Base # please do not remove this
#         include DataMapper::Persistable
#         property :created_at, :timestamp
#       end
#     }.should raise_error(ArgumentError)
#   end
# end

# describe DataMapper::Adapters::Sql::Mappings do
#   
#   it "should return the same Table instance for two objects mapped to the same database table" do
#     # Refers to the same Table instance
#     repository.table(Person) == repository.table(SalesPerson)
#   end
#   
#   it "should have one super-set of total mapped columns" do
#     # Refers to the mapped columns
#     repository.table(Person).columns == repository.table(SalesPerson).columns
#   end
#   
#   it "should have one set of columns that represents the actual database" do
#     # Refers to the actual columns in the database, which may/are-likely-to-be different
#     # than the mapped columns, sometimes just because your models are dealing with
#     # a legacy database where not every column is mapped to the new model, so this
#     # is expected.
#     repository.table(Person).send(:database_columns) == repository.table(SalesPerson).send(:database_columns)
#   end
#   
#   it "should have two different sets of mapped properties that point to subsets of the Table columns" do
#     # pending("This one still needs some love to pass.")
#     table = repository.table(Person)
#     
#     # Every property's column should be represented in the Table's column mappings.
#     Person.properties.each do |property|
#       table.columns.should include(property.column)
#     end
#     
#     # For both models in the STI setup...
#     SalesPerson.properties.each do |property|
#       repository.table(SalesPerson).columns.should include(property.column)
#     end
#     
#     # Even though Person's properties are fewer than a SalesPerson's
#     Person.properties.size.should_not eql(SalesPerson.properties.size)
#     
#     # And Person's properties should be a subset of a SalesPerson's
#     Person.properties.each do |property|
#       SalesPerson.properties.map(&:column).should include(property.column)
#     end
#   end
#   
# end
