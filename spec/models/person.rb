class Person #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property [:name, :occupation], :string
  property :age, :integer
  property :type, :class
  property :notes, :text
  property :date_of_birth, :date
  
  embed :address, :prefix => true do
    property :street, :string
    property :city, :string
    property :state, :string, :size => 2
    property :zip_code, :string, :size => 10
    
    def city_state_zip_code
      "#{city}, #{state} #{zip_code}"
    end
    
  end
  
  belongs_to :career

  before_save :before_save_callback

  def before_save_callback
    @notes = "Lorem ipsum dolor sit amet"
  end

end
