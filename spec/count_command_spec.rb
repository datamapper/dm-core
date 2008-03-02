require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::AbstractAdapter, "count()" do
    
  before(:all) do
    fixtures(:zoos)
    fixtures(:projects)
  end

  it "should return a count of the selected table" do
    Zoo.count.should be_a_kind_of(Integer)
    Zoo.count.should == Zoo.all.size
  end
  
  it "should accept finder style options" do
    # Hash-style (with SymbolOperators)
    Zoo.count(:name => 'Dallas').should == Zoo.all(:name => 'Dallas').length
    Zoo.count(:name.not => nil).should == Zoo.all(:name.not => nil).length
    Zoo.count(:name.not => nil, :notes => nil).should == Zoo.all(:name.not => nil, :notes => nil).length
    Zoo.count(:name.like => '%.%').should == Zoo.all(:name.like => '%.%').length
    
    # :conditions
    Zoo.count(:conditions => ["name = ?", 'Dallas']).should == Zoo.all(:conditions => ["name = ?", 'Dallas']).length
    
    # mix and match
    Zoo.count(:notes => nil, :conditions => ["name = ?", 'Dallas']).should == Zoo.all(:notes => nil, :conditions => ["name = ?", 'Dallas']).length
  end
  
  it "should respect paranoia" do
    p = Project[3]
    p.destroy!
    
    Project.count.should == Project.all.length
    # clean up
    p.deleted_at = nil
    p.save
  end
  
  #This won't work at the moment, hopefully before 0.3.0
  it "should do distinct counting" do
    #Zoo.count(:distinct => :name).should == Zoo.all.length # there all distinct in the fixtures
    #Zoo.count(:distinct => :name, :notes.not => nil).should == Zoo.all(:notes.not => nil).length
    #Zoo.count(:distinct => :name, :conditions => ["notes is not null"]).should == Zoo.all(:notes.not => nil).length
  end
end
