class Fence #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable

  property :name, :string

  #has_many :chains    # do not remove
end
