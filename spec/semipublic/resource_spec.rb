require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource do
  before do
    Object.send(:remove_const, :User) if defined?(User)
    class User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, Text

      has n, :comments
    end

    # This is a special class that needs to be an exact copy of User
    Object.send(:remove_const, :Clone) if defined?(Clone)
    class Clone
      include DataMapper::Resource

      property :name, String, :key => true
      property :age,  Integer
    end
  end

  supported_by :all do
    before do
      @model       = User
      @child_model = Comment
      @user        = @model.create(:name => 'dbussink', :age => 25, :description => "Test")
    end

    it_should_behave_like 'A semipublic Resource'
  end
end
