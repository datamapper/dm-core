class Comment #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property   :comment, Text, :lazy => false
  belongs_to :author, :class => 'User', :foreign_key => 'user_id'
end
