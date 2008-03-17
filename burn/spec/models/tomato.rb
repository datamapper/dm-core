class Tomato
  include DataMapper::Persistable
  
  def initialize(details = nil)
    super
    
    @name = 'Ugly'
    @init_run = true
    @bruised = true
  end
  
  def initialized?
    @init_run
  end
  
  property :name, String
  
  def heal!
    @bruised = false
  end
  
  def bruised?
    @bruised
  end
end
