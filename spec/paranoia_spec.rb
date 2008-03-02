require File.dirname(__FILE__) + "/spec_helper"

describe 'Paranoia' do
  
  before(:all) do
    class Scared #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable
      
      property :name, :string
      property :deleted_at, :datetime
    end
    
    Scared.auto_migrate!
  end
  
  after(:all) do
    repository.table(Scared).drop!
  end
  
  it "should not be found" do
    cat = Scared.create(:name => 'bob')
    
    repository.query('SELECT name FROM scareds').should have(1).entries
    
    cat2 = Scared.first(:name => 'bob')
    cat2.should_not be_nil
    cat2.should be_a_kind_of(Scared)
    
    cat.destroy!
    
    Scared.first(:name => 'bob').should be_nil
    
    Scared.first.should be_nil
    
    repository.query('SELECT name FROM scareds').should have(1).entries
  end
  
end
