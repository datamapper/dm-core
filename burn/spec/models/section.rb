class Section #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property :title, String
  property :created_at, DateTime
  
  belongs_to :project
end
