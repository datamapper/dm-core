class Task #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable

  property :name, String, :default => "No Name", :index => :unique
  property :notes, String
  property :completed, TrueClass, :default => false

  has_and_belongs_to_many :tasks
end
