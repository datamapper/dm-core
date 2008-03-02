require File.dirname(__FILE__) + "/spec_helper"

describe "Magic Columns" do

  it "should update updated_at on save" do
    zoo = Zoo.new(:name => 'Mary')
    zoo.save
    zoo.updated_at.should be_a_kind_of(Time)
  end

  it "should not update created_at when updating a model" do
    section = Section.create(:title => "Mars")
    old_created_at = section.created_at
    section.update_attributes(:title => "Mars2!")
    section.created_at.should eql(old_created_at)
  end

  it "should not set the created_at/on fields if already set on creation" do
    section = Section.new(:title => "Mars")
    fixed_created_at = Time::now - 2600
    section.created_at = fixed_created_at
    section.save
    section.created_at.should eql(fixed_created_at)
  end

end