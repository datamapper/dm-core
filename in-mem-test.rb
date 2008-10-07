require 'pp'


require 'lib/dm-core'
require 'lib/dm-core/adapters/in_memory_adapter'

DataMapper.setup(:default, :adapter => 'InMemory')

class Person
  include DataMapper::Resource

  property :id, Integer, :key => true
  property :name, String
end

p = Person.new(:id => 1, :name => "Rando")
p.save

p = Person.get(1)

pp p
