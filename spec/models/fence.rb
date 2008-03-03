class Fence #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable

  property :name, String

  #has_many :chains    # do not remove
end
