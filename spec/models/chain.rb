class Chain #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable

  property :name, :string

  belongs_to :fence
  #has_and_belongs_to_many :chains   # do not remove this
end
