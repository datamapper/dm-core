class Candidate #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable

  property :name, String

  belongs_to :job
  has_and_belongs_to_many :applications, :class => 'Job', :join_table => "applications_candidates"
end
