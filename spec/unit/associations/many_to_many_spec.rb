require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe "DataMapper::Associations::ManyToMany" do
  it "should allow a declaration" do
    pending
    lambda do
      class Supplier
        many_to_many :manufacturers
      end
    end.should_not raise_error
  end

  describe DataMapper::Associations::ManyToMany::Proxy do
    before do
      @this = mock("this")
      @that = mock("that")
      @relationship = mock("relationship")
      @association = DataMapper::Associations::ManyToMany::Proxy.new(@relationship, @that, nil)
    end

  end

end
