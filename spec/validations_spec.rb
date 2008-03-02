require File.dirname(__FILE__) + "/spec_helper"

describe Validatable do
  
  before(:all) do
    class Cow
      
      include DataMapper::CallbacksHelper
      include DataMapper::Validations
      
      attr_accessor :name, :age
    end
  end
  
  it 'should allow you to specify not-null fields for different events' do
    class Cow
      validations.clear
      validates_presence_of :name, :event => :save
    end
    
    betsy = Cow.new
    betsy.valid?.should == true

    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name must not be blank'
    
    betsy.name = 'Betsy'
    betsy.valid?(:save).should == true
  end
  
  it 'should be able to use ":on" for an event alias' do
    class Cow
      validations.clear
      validates_presence_of :name, :age, :on => :create
    end
    
    maggie = Cow.new
    maggie.valid?.should == true
    
    maggie.valid?(:create).should == false
    maggie.errors.full_messages.should include('Age must not be blank')
    maggie.errors.full_messages.should include('Name must not be blank')
    
    maggie.name = 'Maggie'
    maggie.age = 29
    maggie.valid?(:create).should == true
  end
  
  it 'should default to a general event if unspecified' do
    class Cow
      validations.clear
      validates_presence_of :name, :age
    end
    
    rhonda = Cow.new
    rhonda.valid?.should == false
    rhonda.errors.should have(2).full_messages
    
    rhonda.errors.full_messages.should include('Age must not be blank')
    rhonda.errors.full_messages.should include('Name must not be blank')
    
    rhonda.name = 'Rhonda'
    rhonda.age = 44
    rhonda.valid?.should == true
  end
  
  it "should always run validations without a specific event" do
    class Cow
      validations.clear
      validates_presence_of :name
      validates_presence_of :age, :on => :save
    end

    isabel = Cow.new
    isabel.valid?.should == false
    isabel.errors.should have(1).full_messages
    isabel.errors.full_messages.should include('Name must not be blank')
    isabel.errors.on(:name).should == ['Name must not be blank']
    
    isabel.valid?(:save).should == false
    isabel.errors.should have(2).full_messages
    
    isabel.errors.full_messages.should include('Age must not be blank')
    isabel.errors.full_messages.should include('Name must not be blank')
    isabel.errors.on(:name).should == ['Name must not be blank']

  end
  
  it 'should have 1 validation error' do    
    class VPOTest
      
      include DataMapper::CallbacksHelper
      include DataMapper::Validations
      
      attr_accessor :name, :whatever
      
      validates_presence_of :name
    end

    o = VPOTest.new
    o.should_not be_valid
    o.errors.should have(1).full_messages
  end
  
  it 'should translate error messages' do
    String::translations["%s must not be blank"] = "%s should not be blank!"
  
    beth = Cow.new
    beth.age = 30
  
    beth.should_not be_valid
  
    beth.errors.full_messages.should include('Name should not be blank!')
  
    String::translations.delete("%s must not be blank")
  end

  it 'should be able to find specific error message' do
    class Cow
      validations.clear
      validates_presence_of :name
    end

    gertie = Cow.new
    gertie.should_not be_valid
    gertie.errors.on(:name).should == ['Name must not be blank']
    gertie.errors.on(:age).should == nil
  end
  
  it "should be able to specify custom error messages" do
    class Cow
      validations.clear
      validates_presence_of :name, :message => 'Give me a name, bub!'
    end
    
    gertie = Cow.new
    gertie.should_not be_valid
    gertie.errors.on(:name).should == ['Give me a name, bub!']    
  end
  
end