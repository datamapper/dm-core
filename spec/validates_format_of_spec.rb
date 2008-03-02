require File.dirname(__FILE__) + "/spec_helper"

context Validatable::ValidatesFormatOf do
  
  before(:all) do
    class Employee

      include DataMapper::CallbacksHelper
      include DataMapper::Validations
      
      attr_accessor :email
    end
  end
  
  it 'must have a valid email address' do
    class Employee
      validations.clear
      validates_format_of :email, :with => :email_address, :on => :save
    end
    
    e = Employee.new
    e.valid?.should == true

    [
      'test test@example.com', 'test@example', 'test#example.com',
      'tester@exampl$.com', '[scizzle]@example.com', '.test@example.com'
    ].all? { |test_email|
      e.email = test_email
      e.valid?(:save).should == false
      e.errors.full_messages.first.should == "#{test_email} is not a valid email address"
    }

    e.email = 'test@example.com'
    e.valid?(:save).should == true
  end
  
  it 'must have a valid organization code' do
    class Employee
      validations.clear
      
      attr_accessor :organization_code
      
      # WARNING: contrived example
      # The organization code must be A#### or B######X12
      validates_format_of :organization_code, :on => :save, :with => /(A\d{4}|[B-Z]\d{6}X12)/
    end
    
    e = Employee.new
    e.valid?.should == true
    
    e.organization_code = 'BLAH :)'
    e.valid?(:save).should == false
    e.errors.full_messages.first.should == 'Organization code is invalid'

    e.organization_code = 'A1234'
    e.valid?(:save).should == true

    e.organization_code = 'B123456X12'
    e.valid?(:save).should == true
  end
  
  
  it 'should allow custom error messages' do
    class Employee
      validations.clear
      validates_format_of :email, :with => :email_address, :on => :save, :message => "Me needs good email, m'kay?"
    end
    
    e = Employee.new
    e.valid?.should == true
    
    e.valid?(:save).should == false
    e.errors.full_messages.first.should == "Me needs good email, m'kay?"
    
  end
  
end
