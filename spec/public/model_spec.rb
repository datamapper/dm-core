require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Model do

  before do 
    class Heffalump 
      include DataMapper::Resource

      property :color,      String, :key => true # TODO: Drop the 'must have a key' limitation
      property :num_spots,  Integer
      property :striped,    Boolean
    end
  end
end
