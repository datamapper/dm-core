require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require 'dm-core/spec/adapter_shared_spec'

describe 'DataMapper::Adapters::PostgresAdapter' do
  before :all do
    class ::Heffalump
      include DataMapper::Resource

      property :id,        Serial
      property :color,     String
      property :num_spots, Integer
      property :striped,   Boolean
    end

    @model = Heffalump
  end

  supported_by :postgres do
    before :all do
      @model.auto_migrate!

      @heff1 = @model.create(:color => 'Black',     :num_spots => 0,   :striped => true)
      @heff2 = @model.create(:color => 'Brown',     :num_spots => 25,  :striped => false)
      @heff3 = @model.create(:color => 'Dark Blue', :num_spots => nil, :striped => false)

      @string_property  = @model.color
      @integer_property = @model.num_spots
    end

    it_should_behave_like 'An Adapter'
  end
end
