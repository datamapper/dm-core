require 'spec_helper'

describe 'Many to One Associations' do
  before :all do
    class ::User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, Text

      has n, :comments
    end

    class ::Comment
      include DataMapper::Resource

      property :id, Serial

      belongs_to :user
    end

    @user_model    = User
    @comment_model = Comment

    @default_value          = @user_model.new(:name => 'dkubb', :age => 34, :description => 'Test')
    @default_value_callable = @user_model.new(:name => 'jdoe',  :age => 21, :description => 'Test')

    @subject_without_default       = @user_model.belongs_to(:without_default,       @user_model, :required => false, :child_key => [ :without_default_id       ])
    @subject_with_default          = @user_model.belongs_to(:with_default,          @user_model, :required => false, :child_key => [ :with_default_id          ], :default => @default_value)
    @subject_with_default_callable = @user_model.belongs_to(:with_default_callable, @user_model, :required => false, :child_key => [ :with_default_callable_id ], :default => lambda { |resource, relationship| @default_value_callable })

    @default_value.with_default          = nil
    @default_value.with_default_callable = nil

    DataMapper.finalize
  end

  supported_by :all do
    before :all do
      @default_value.save
      @default_value_callable.save
    end

    before :all do
      comment = @comment_model.create(:user => { :name => 'dbussink', :age => 25, :description => 'Test' })

      @user = @comment_model.get(*comment.key).user
    end

    it_should_behave_like 'A semipublic Resource'

    describe 'acts like a subject' do
      before do
        @resource = @user_model.new(:name => 'A subject')
      end

      it_should_behave_like 'A semipublic Subject'
    end
  end
end
