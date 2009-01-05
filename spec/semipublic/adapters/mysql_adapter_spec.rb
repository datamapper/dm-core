require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'DataMapper::Adapters::MysqlAdapter' do
  supported_by :mysql do
    before do
      class Heffalump
        include DataMapper::Resource

        property :id,         Serial
        property :color,      String
        property :num_spots,  Integer
        property :striped,    Boolean
      end

      Heffalump.auto_migrate!

      @heff1 = Heffalump.create(:color => 'Black',     :num_spots => 0,   :striped => true)
      @heff2 = Heffalump.create(:color => 'Brown',     :num_spots => 25,  :striped => false)
      @heff3 = Heffalump.create(:color => 'Dark Blue', :num_spots => nil, :striped => false)

      @model = Heffalump
      @string_property = @model.color
      @integer_property = @model.num_spots
    end

    it_should_behave_like 'An Adapter'
  end
end
