require File.expand_path(File.join(File.dirname(__FILE__), '..', "..", 'spec_helper'))
require SPEC_ROOT + 'lib/adapter_shared_spec'

describe DataMapper::Adapters::InMemoryAdapter do
  supported_by :in_memory do
    before do
      class Heffalump
        include DataMapper::Resource

        property :id,         Serial
        property :color,      String
        property :num_spots,  Integer
        property :striped,    Boolean
      end

      @heff1 = Heffalump.create(:color => 'Black',     :num_spots => 0,   :striped => true)
      @heff2 = Heffalump.create(:color => 'Brown',     :num_spots => 25,  :striped => false)
      @heff3 = Heffalump.create(:color => 'Dark Blue', :num_spots => nil, :striped => false)

      @model = Heffalump
      @property = @model.color
      @resource = Heffalump.new(:color => "Mauve")
    end

    after do
      # Commenting this out, this wasn't working with shared adapter spec -- dph
      # Heffalump.all.destroy!
    end

    it 'should successfully save an object' do
      @heff1.new_record?.should be_false
    end

    it 'should be able to get the object' do
      Heffalump.get(1).should == @heff1
    end

    it 'should be able to get all the objects' do
      Heffalump.all.should == [@heff1, @heff2, @heff3]
    end

    it 'should be able to search for objects with equal value' do
      Heffalump.all(:striped => true).should == [@heff1]
    end

    it 'should be able to search for objects included in an array of values' do
      Heffalump.all(:num_spots => [ 25, 50, 75, 100 ]).should == [@heff2]
    end

    it 'should be able to search for objects included in a range of values' do
      Heffalump.all(:num_spots => 25..100).should == [@heff2]
    end

    it 'should be able to search for objects with nil value' do
      Heffalump.all(:num_spots => nil).should == [@heff3]
    end

    it 'should be able to search for objects with not equal value' do
      Heffalump.all(:striped.not => true).should == [@heff2, @heff3]
    end

    it 'should be able to search for objects not included in an array of values' do
      Heffalump.all(:num_spots.not => [ 25, 50, 75, 100 ]).should == [@heff1, @heff3]
    end

    it 'should be able to search for objects not included in a range of values' do
      Heffalump.all(:num_spots.not => 25..100).should == [@heff1, @heff3]
    end

    it 'should be able to search for objects with not nil value' do
      Heffalump.all(:num_spots.not => nil).should == [@heff1, @heff2]
    end

    it 'should be able to search for objects that match value' do
      Heffalump.all(:color.like => 'Bl').should == [@heff1, @heff3]
    end

    it 'should be able to search for objects with value greater than' do
      Heffalump.all(:num_spots.gt => 0).should == [@heff2]
    end

    it 'should be able to search for objects with value greater than or equal to' do
      Heffalump.all(:num_spots.gte => 0).should == [@heff1, @heff2]
    end

    it 'should be able to search for objects with value less than' do
      Heffalump.all(:num_spots.lt => 1).should == [@heff1]
    end

    it 'should be able to search for objects with value less than or equal to' do
      Heffalump.all(:num_spots.lte => 0).should == [@heff1]
    end

    it 'should be able to order the objects ascending' do
      Heffalump.all(:order => [ :color ]).should == [@heff1, @heff2, @heff3]
    end

    it 'should be able to order the objects descending' do
      Heffalump.all(:order => [ :color.desc ]).should == [@heff3, @heff2, @heff1]
    end

    it 'should be able to limit the objects' do
      Heffalump.all(:limit => 2).should == [@heff1, @heff2]
    end

    it 'should be able to update an object' do
      @heff1.num_spots = 10
      @heff1.save
      Heffalump.get(1).num_spots.should == 10
    end

    it 'should be able to destroy an object' do
      @heff1.destroy
      Heffalump.all.size.should == 2
    end

    it_should_behave_like 'An Adapter'
  end
end
