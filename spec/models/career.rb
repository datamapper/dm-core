class Career #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property :name, String, :key => true
  
  has_many :followers, :class => 'Person'
end
