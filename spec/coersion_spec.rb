require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::Sql::Coersion do
  
  before(:all) do
    @coersive = Class.new do
      include DataMapper::Adapters::Sql::Coersion
    end.new
  end
  
  it 'should cast to a BigDecimal' do
    target = BigDecimal.new('7.2')
    @coersive.type_cast_decimal('7.2').should == target
    @coersive.type_cast_decimal(7.2).should == target
  end
  
  it 'should store and load a date' do
    dob = Date::today
    bob = Person.create(:name => 'DateCoersionTest', :date_of_birth => dob)
    
    bob2 = Person.first(:name => 'DateCoersionTest')
    
    bob.date_of_birth.should eql(dob)
    bob2.date_of_birth.should eql(dob)
  end
  
  it 'should cast to a Date' do
    target = Date.civil(2001, 1, 1)
    
    @coersive.type_cast_date('2001-1-1').should eql(target)
    @coersive.type_cast_date(target.dup).should eql(target)
    @coersive.type_cast_date(DateTime::parse('2001-1-1')).should eql(target)
    @coersive.type_cast_date(Time::parse('2001-1-1')).should eql(target)
  end

  it 'should cast to a String' do
    target = "\n\ttest\n\n\ntest\n\n"

    @coersive.type_cast_text(target).should == target
  end
end
