require File.dirname(__FILE__) + "/spec_helper"

describe Validatable::ValidatesLengthOf do
  
  before(:all) do
    class Cow
      
      include DataMapper::CallbacksHelper
      include DataMapper::Validations
      
      attr_accessor :name, :age
    end
  end
  
  it 'should not have a name shorter than 3 characters' do
    class Cow
      validations.clear
      validates_length_of :name, :minimum => 3, :event => :save
    end
    
    betsy = Cow.new
    betsy.valid?.should == true

    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name must be more than 2 characters long'

    betsy.name = 'Be'
    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name must be more than 2 characters long'

    betsy.name = 'Bet'
    betsy.valid?(:save).should == true

    betsy.name = 'Bets'
    betsy.valid?(:save).should == true
  end


  it 'should not have a name longer than 10 characters' do
    class Cow
      validations.clear
      validates_length_of :name, :maximum => 10, :event => :save
    end
    
    betsy = Cow.new
    betsy.valid?.should == true
    betsy.valid?(:save).should == true

    betsy.name = 'Testicular Fortitude'
    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name must be less than 11 characters long'

    betsy.name = 'Betsy'
    betsy.valid?(:save).should == true
  end

  it 'should have a name that is 8 characters long' do
    class Cow
      validations.clear
      validates_length_of :name, :is => 8, :event => :save
    end
    
    # Context is not save
    betsy = Cow.new
    betsy.valid?.should == true
    
    # Context is :save
    betsy.valid?(:save).should == false

    betsy.name = 'Testicular Fortitude'
    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name must be 8 characters long'

    betsy.name = 'Samooela'
    betsy.valid?(:save).should == true
  end

  it 'should have a name that is between 10 and 15 characters long' do
    class Cow
      validations.clear
      validates_length_of :name, :within => (10..15), :event => :save
    end
    
    # Context is not save
    betsy = Cow.new
    betsy.valid?.should == true
    
    # Context is :save
    betsy.valid?(:save)
    betsy.errors.full_messages.first
    
    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name must be between 10 and 15 characters long'
    
    betsy.name = 'Smoooooot'
    betsy.valid?(:save).should == false

    betsy.name = 'Smooooooooooooooooooot'
    betsy.valid?(:save).should == false

    betsy.name = 'Smootenstein'
    betsy.valid?(:save).should == true
  end
  
  it 'should allow custom error messages' do
    class Cow
      validations.clear
      validates_length_of :name, :is => 8, :event => :save, :message => '8 letters, no more, no less.'
    end
    
    betsy = Cow.new
    betsy.valid?.should == true
    
    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == '8 letters, no more, no less.'
  end
end