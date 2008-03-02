require File.dirname(__FILE__) + "/spec_helper"

# Can't describe DataMapper::Persistable because
# rspec will include it for some crazy reason!
describe "DataMapper::Persistable" do
  
  it "should be able to add a dependency for a class not yet defined" do
    
    $happy_cow_defined = false
    
    DataMapper::Persistable.dependencies.add('HappyCow') do |klass|
      klass.should eql(Object.const_get('HappyCow'))
      repository.table(klass).key.name.should eql(:name)
      $happy_cow_defined = true
    end
    
    class HappyCow #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable
      
      property :name, :string, :key => true
    end
    
    # Dependencies are not resolved until you try to access the key for a table...
    repository.table(HappyCow).key
    
    raise 'Dependency not called for HappyCow :-(' unless $happy_cow_defined
  end
  
end
