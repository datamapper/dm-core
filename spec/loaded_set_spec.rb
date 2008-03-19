require __DIR__.parent + 'lib/data_mapper/repository'
require __DIR__.parent + 'lib/data_mapper/resource'
require __DIR__.parent + 'lib/data_mapper/loaded_set'
require __DIR__ + 'mock_adapter'

describe "DataMapper::LoadedSet" do
  
  it "should be able to materialize arbitrary objects" do
    
    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]
    
    cow = Class.new do
      include DataMapper::Resource
      
      property :name, String, :key => true
      property :age, Fixnum
    end

    properties = Hash[*cow.properties(:default).zip([0, 1]).flatten]    
    set = DataMapper::LoadedSet.new(DataMapper::repository(:default), cow, properties)
    
    set.materialize!(['Bob', 10])
    set.materialize!(['Nancy', 11])
    
    results = set.to_a
    results.should have(2).entries
    
    bob, nancy = results[0], results[1]
    p bob.instance_variables
    bob.name.should eql('Bob')
    bob.age.should eql(10)
    
    nancy.name.should eql('Nancy')
    nancy.age.should eql(11)
  end
end