class Post #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
  
  property :title, :string
  property :created_at, :datetime
  
  def next
    Post.first(:created_at.gte => self.created_at, :id.gt => self.id, :order => "created_at, id")
  end

  def previous
    Post.first(:created_at.lte => self.created_at, :id.lt => self.id, :order => "created_at DESC, id DESC")
  end
end
