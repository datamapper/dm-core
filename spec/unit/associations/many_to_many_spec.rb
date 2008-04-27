require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe "DataMapper::Associations::ManyToMany" do

  before do
    @adapter = DataMapper::Repository.adapters[:relationship_spec] || DataMapper.setup(:relationship_spec, 'mock://localhost')
  end

  it "should allow a declaration" do

    lambda do
      class Supplier
        many_to_many :manufacturers
      end
    end.should_not raise_error
  end

  describe DataMapper::Associations::ManyToMany::Instance do
    before do
      @this = mock("this")
      @that = mock("that")
      @relationship = mock("relationship")
      @association = DataMapper::Associations::ManyToMany::Instance.new(@relationship, @that, nil)
    end

  end

end
