class Project #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property :title, :string
  property :description, :string
  property :deleted_at, :datetime

  has_many :sections
  
  before_create :create_main_section
  
  def tickets
    return [] if sections.empty?
    sections.map { |section| section.tickets }
  end
  
  
  def set_us_up_the_bomb=(val)
    @set_us_up_the_bomb = !val.blank?
  end
  
  def set_up_for_bomb?
    @set_us_up_the_bomb
  end
  
  def wery_sneaky?
    @be_wery_sneaky
  end
  
  
  private
  
  def create_main_section
    sections << Section.find_or_create(:title => "Main") if sections.empty?
  end
  
  def be_wery_sneaky=(val)
    @be_wery_sneaky = val
  end

end
