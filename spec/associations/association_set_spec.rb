require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require __DIR__.parent.parent + 'lib/data_mapper/associations/association_set'

DA = DataMapper::Associations

describe "DataMapper::Associations::AssociationSet" do
  
  before :all do
    @relationship = DataMapper::Associations::Relationship.new(
      :manufacturer,
      :default,
      ['Vehicle', [:manufacturer_id]],
      ['Manufacturer', nil]
    )
  end
  
  # We're going to give the Relationship the blocks. AMAZING!!!!
  # SCARY!!! NEVER!! BEFORE! SEEN.
  # it "should require a block" do
  #   lambda { DA::AssociationSet.new(@relationship, nil) }.should raise_error
  # end
  # 
  # it "should lazy load the provided block" do
  #   set = DA::AssociationSet.new(@relationship, nil) do |set|
  #     [1, 2]
  #   end
  #   set.send(:instance_variable_get, "@entries").should be_nil
  #   set.entries.should == [1, 2]
  #   set.send(:instance_variable_get, "@entries").should == [1, 2]
  # end
  # 
  # it "should lazy load on #first" do
  #   set = DA::AssociationSet.new(@relationship, nil) do |set|
  #     [1, 2]
  #   end
  #   set.first.should == 1
  # end
  # 
  # it "should lazy load on #each" do
  #   set = DA::AssociationSet.new(@relationship, nil) do |set|
  #     [1, 2]
  #   end
  #   set.each do |x|
  #     x.should be_a_kind_of(Integer)
  #   end
  # end
  
end