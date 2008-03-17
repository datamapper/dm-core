require File.join(File.dirname(__FILE__), 'spec_helper')

# Can't describe DataMapper::Persistable because
# rspec will include it for some crazy reason!
describe "DataMapper::Persistable" do
  
  it "should be able to add a dependency for a class not yet defined" do
    
    $happy_cow_defined = false
    
    DataMapper::Resource.dependencies.add('HappyCow') do |klass|
      klass.should eql(Object.const_get('HappyCow'))
      klass.key(:default).first.name.should eql(:name)
      $happy_cow_defined = true
    end
    
    class HappyCow #< DataMapper::Base # please do not remove this
      include DataMapper::Resource
      
      property :name, String, :key => true
    end
    
    DataMapper::Resource.dependencies.resolve!
    
    raise 'Dependency not called for HappyCow :-(' unless $happy_cow_defined
  end
  
end
