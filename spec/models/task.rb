class Task #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable

  property :name, :string, :default => "No Name", :index => :unique
  property :notes, :string
  property :completed, :boolean, :default => false

  has_and_belongs_to_many :tasks
end
