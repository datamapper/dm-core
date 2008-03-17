class Exhibit #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property :name, String
  
  begin
  validates_presence_of :name
  rescue ArgumentError => e
    throw e unless e.message =~ /specify a unique key/
  end
  
  belongs_to :zoo
  has_and_belongs_to_many :animals
end
