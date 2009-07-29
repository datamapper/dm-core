require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

# TODO: combine this into many_to_one_spec.rb

describe 'Many to One Associations when foreign key is part of a composite key, with an integer and a boolean making up the composite key' do
  before :all do
    class ::ManyModel
      include DataMapper::Resource

      property :integer_key, Integer, :key => true
      property :boolean_key, Boolean, :key => true

      belongs_to :one_model, :child_key => [ :integer_key ]
    end

    class ::OneModel
      include DataMapper::Resource

      property :integer_key, Integer, :key => true

      has n, :many_models, :child_key => [ :integer_key ]
    end
  end

  supported_by :all do
    before :all do
      @one  = OneModel.create(:integer_key => 1)
      @many = ManyModel.create(:integer_key => 1, :boolean_key => false)
    end

    it 'should be able to access parent' do
      @many.one_model.should == @one
    end

    it 'should be able to access the child' do
      @one.many_models.should == [ @many ]
    end
  end
end
