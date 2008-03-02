class Tomato
  include DataMapper::Persistable
  
  ATTRIBUTES << :bruised
  
  def initialize(details = nil)
    super
    
    @name = 'Ugly'
    @init_run = true
    @bruised = true
  end
  
  def initialized?
    @init_run
  end
  
  property :name, :string
  
  def heal!
    @bruised = false
  end
  
  def bruised?
    @bruised
  end
end
