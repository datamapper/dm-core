class Person #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property :name, String
  property :occupation, String
  property :age, Fixnum
  property :type, Class
  property :notes, Text
  property :date_of_birth, Date
  
  # embed :address, :prefix => true do
  #   property :street, String
  #   property :city, String
  #   property :state, String, :size => 2
  #   property :zip_code, String, :size => 10
  #   
  #   def city_state_zip_code
  #     "#{city}, #{state} #{zip_code}"
  #   end
  #   
  # end
  
  belongs_to :career

  before_save :before_save_callback

  def before_save_callback
    @notes = "Lorem ipsum dolor sit amet"
  end

end
