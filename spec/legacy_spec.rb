require File.join(File.dirname(__FILE__), 'spec_helper')

describe 'Legacy mappings' do
  
  it('should allow models to map with custom attribute names') do
    Fruit.first.name.should == 'Kiwi'
  end
  
  it('should allow custom foreign-key mappings') do
    repository do
      Fruit.first(:name => 'Watermelon').devourer_of_souls.should == Animal.first(:name => 'Cup')
      Animal.first(:name => 'Cup').favourite_fruit.should == Fruit.first(:name => 'Watermelon')
    end
  end
  
end
