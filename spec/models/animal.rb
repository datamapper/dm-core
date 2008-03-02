class Animal #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable

  property :name, :string, :default => "No Name", :index => :unique
  property :notes, :text
  property :nice, :boolean
  
  has_one :favourite_fruit, :class => 'Fruit', :foreign_key => 'devourer_id'
  has_and_belongs_to_many :exhibits
  
  DEFAULT_LIMIT = 5
end
