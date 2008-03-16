require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe DataMapper::Adapters::DataObjectAdapter do
  
  before(:all) do
    fixtures(:zoos)
  end
  
  if ENV['ADAPTER'] == 'postgresql'
    it "should be able to be given a port" do
      options = {
        :adapter => 'postgresql',
        :database => 'data_mapper_1',
        :port => 4001
      }
      repo = DataMapper::Repository.setup(:my_postgres, options)
      repo.port.should == 4001
    end
  end
  
  it "should use DB defaults when creating an empty record" do
    comment = Comment.create({})
    comment.new_record?.should be_false
  end
  
  it "should raise an argument error on create if an attribute value is not a primitive" do
    lambda { Zoo.create(:name => [nil, 'bob']) }.should raise_error(ArgumentError)
  end

  it "should accept a subclass as a valid type if the parent is a valid type"
end
