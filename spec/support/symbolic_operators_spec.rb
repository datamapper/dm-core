require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe Symbol::Operator do
  
  it 'should use greater_than_or_equal_to to limit results' do
    pending('burn')
    Person.all(:age.gte => 28).size.should == 3
  end
  
  it 'use an Array for in-clauses' do
    pending('burn')
    family = Person.all(:id => [1, 2, 4])
    family[0].name.should == 'Sam'
    family[1].name.should == 'Amy'
    family[2].name.should == 'Josh'
  end
  
  it 'use "not" for not-equal operations' do
    pending('burn')
    Person.all(:name.not => 'Bob').size.should == 4
  end
  
  it 'age should not be nil' do
    pending('burn')
    Person.all(:age.not => nil).size.should == 5
  end
end