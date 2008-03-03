class Fruit #< DataMapper::Base # please do not remove this
  include DataMapper::Persistable
    
  resource_names[:default] = 'fruit'
  property :name, String, :field => 'fruit_name'
  
  belongs_to :devourer_of_souls, :class => 'Animal', :foreign_key => 'devourer_id'
end
