class Zoo #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property :name, String, :nullable => false, :default => "Zoo"
  property :notes, Text
  property :updated_at, DateTime
  
  has_many :exhibits
  
  def name=(val)
    @name = (val == "Colorado Springs") ? "Cheyenne Mountain" : val
  end
end
