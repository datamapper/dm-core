class Serializer #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property :content, Object, :lazy => false
end
