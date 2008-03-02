require File.dirname(__FILE__) + "/spec_helper"

describe Validatable::ValidatesConfirmationOf do
  
  before(:all) do
    class Cow

      include DataMapper::CallbacksHelper
      include DataMapper::Validations
      
      attr_accessor :name, :name_confirmation, :age
    end
  end
  
  it 'should pass validation' do
    class Cow
      validations.clear
      validates_confirmation_of :name, :event => :save
    end
    
    betsy = Cow.new
    betsy.valid?.should == true

    betsy.name = 'Betsy'
    betsy.name_confirmation = ''
    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name does not match the confirmation'

    betsy.name = ''
    betsy.name_confirmation = 'Betsy'
    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name does not match the confirmation'

    betsy.name = 'Betsy'
    betsy.name_confirmation = 'Betsy'
    betsy.valid?(:save).should == true
  end
  
  it 'should allow allow a custom error message' do
    class Cow
      validations.clear
      validates_confirmation_of :name, :event => :save, :message => 'You confirm name NOW or else.'
    end
    
    betsy = Cow.new
    betsy.valid?.should == true

    betsy.name = 'Betsy'
    betsy.name_confirmation = ''
    betsy.valid?(:save).should == false

    betsy.errors.full_messages.first.should == 'You confirm name NOW or else.'
  end
  
end