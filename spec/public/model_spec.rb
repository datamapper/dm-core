require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Model do
  before do
    class ::Heffalump
      include DataMapper::Resource

      property :id,         Serial
      property :color,      String
      property :num_spots,  Integer
      property :striped,    Boolean
    end

  end

  supported_by :all do

    before do
      @heff1 = Heffalump.create(:color => 'Black',     :num_spots => 0,   :striped => true)
      @heff2 = Heffalump.create(:color => 'Brown',     :num_spots => 25,  :striped => false)
      @heff3 = Heffalump.create(:color => 'Dark Blue', :num_spots => nil, :striped => false)
    end

    it 'should successfully save an object' do
      @heff1.saved?.should be_true
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

    it 'should be able to search for objects with value less than or equal to' do
      Heffalump.all(:num_spots.lte => 0).should == [@heff1]
    end

    it 'should be able to order the objects ascending' do
      Heffalump.all(:order => [ :color ]).should == [@heff1, @heff2, @heff3]
    end

    it 'should be able to order the objects descending' do
      Heffalump.all(:order => [ :color.desc ]).should == [@heff3, @heff2, @heff1]
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

    it { Heffalump.should respond_to(:copy) }

    with_alternate_adapter do
      describe '#copy' do
        describe 'between identical models' do
          before do
            @return = @resources = Heffalump.copy(:default, @alternate_adapter.name)
          end

          it 'should return an Enumerable' do
            @return.should be_a_kind_of(Enumerable)
          end

          it 'should return Resources' do
            @return.each { |r| r.should be_a_kind_of(DataMapper::Resource) }
          end

          it 'should have each Resource set to the expected Repository' do
            @resources.each { |r| r.repository.name.should == @alternate_adapter.name }
          end

          it 'should create the Resources in the expected Repository' do
            Heffalump.all(:repository => repository(@alternate_adapter.name)).should == @resources
          end
        end

        describe 'between different models' do
          before do
            # make sure the default repository is empty
            Heffalump.all(:repository => @repository).destroy!

            # add an extra property to the alternate model
            repository(@alternate_adapter.name) do
              Heffalump.property :status, String, :default => 'new'
            end

            if Heffalump.respond_to?(:auto_migrate!)
              Heffalump.auto_migrate!(@alternate_adapter.name)
            end

            # add new resources to the alternate repository
            repository(@alternate_adapter.name) do
              @heff1 = Heffalump.create(:color => 'Black',     :num_spots => 0,   :striped => true)
              @heff2 = Heffalump.create(:color => 'Brown',     :num_spots => 25,  :striped => false)
              @heff3 = Heffalump.create(:color => 'Dark Blue', :num_spots => nil, :striped => false)
            end

            # copy from the alternate to the default repository
            @return = @resources = Heffalump.copy(@alternate_adapter.name, :default)
          end

          it 'should return an Enumerable' do
            @return.should be_a_kind_of(Enumerable)
          end

          it 'should return Resources' do
            @return.each { |r| r.should be_a_kind_of(DataMapper::Resource) }
          end

          it 'should have each Resource set to the expected Repository' do
            @resources.each { |r| r.repository.name.should == :default }
          end

          it 'should create the Resources in the expected Repository' do
            Heffalump.all.should == @resources
          end
        end
      end
    end
  end

end
