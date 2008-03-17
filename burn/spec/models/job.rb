class Job #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable

  property :name, String
  property :hours, Fixnum, :default => 0
  property :days, Fixnum

  has_and_belongs_to_many :candidates, :join_table => "applications_candidates"
end
