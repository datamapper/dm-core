share_examples_for 'An Adapter' do

  def self.adapter_supports?(*methods)

    # FIXME obviously this needs a real fix!
    # --------------------------------------
    # Probably, delaying adapter_supports?
    # to be executed after DataMapper.setup
    # has been called will solve our current
    # problem with described_type() being nil
    # for as long as DataMapper.setup wasn't
    # called
    return true if ENV['ADAPTER_SUPPORTS'] == 'all'

    methods.all? do |method|
      # TODO: figure out a way to see if the instance method is only inherited
      # from the Abstract Adapter, and not defined in it's class.  If that is
      # the case return false

      # CRUD methods can be inherited from parent class
      described_type.instance_methods.any? { |instance_method| method.to_s == instance_method.to_s }
    end
  end

  # Hack to detect cases a let(:heffalump_model) is not present
  unless instance_methods.map(&:to_s).include?('heffalump_model')
    # This is the default Heffalump model. You can replace it with your own
    # (using let/let!) # but # be shure the replacement provides the required
    # properties.
    let(:heffalump_model) do
      model = Class.new do
        include DataMapper::Resource

        property :id,        DataMapper::Property::Serial
        property :color,     DataMapper::Property::String
        property :num_spots, DataMapper::Property::Integer
        property :striped,   DataMapper::Property::Boolean

        # This is needed for DataMapper.finalize
        def self.name; 'Heffalump'; end
      end

      DataMapper.finalize

      model
    end
  end

  before :all do
    raise '+#adapter+ should be defined in a let(:adapter) block' unless respond_to?(:adapter)
    raise '+#repository+ should be defined in a let(:repository) block' unless respond_to?(:repository)

    DataMapper.finalize

    # create all tables and constraints before each spec
    if repository.respond_to?(:auto_migrate!)
      heffalump_model.auto_migrate!
    end
  end

  if adapter_supports?(:create)
    describe '#create' do
      after do
        heffalump_model.destroy
      end

      it 'should not raise any errors' do
        lambda {
          heffalump_model.create(:color => 'peach')
        }.should_not raise_error
      end

      it 'should set the identity field for the resource' do
        heffalump = heffalump_model.new(:color => 'peach')
        heffalump.id.should be_nil
        heffalump.save
        heffalump.id.should_not be_nil
      end
    end
  else
    it 'needs to support #create'
  end

  if adapter_supports?(:read)
    describe '#read' do
      before :all do
        @heffalump = heffalump_model.create(:color => 'brownish hue')
        #just going to borrow this, so I can check the return values
        @query = heffalump_model.all.query
      end

      after :all do
        heffalump_model.destroy
      end

      it 'should not raise any errors' do
        lambda {
          heffalump_model.all()
        }.should_not raise_error
      end

      it 'should return stuff' do
        heffalump_model.all.should include(@heffalump)
      end
    end
  else
    it 'needs to support #read'
  end

  if adapter_supports?(:update)
    describe '#update' do
      before do
        @heffalump = heffalump_model.create(:color => 'indigo')
      end

      after do
        heffalump_model.destroy
      end

      it 'should not raise any errors' do
        lambda {
          @heffalump.color = 'violet'
          @heffalump.save
        }.should_not raise_error
      end

      it 'should not alter the identity field' do
        id = @heffalump.id
        @heffalump.color = 'violet'
        @heffalump.save
        @heffalump.id.should == id
      end

      it 'should update altered fields' do
        @heffalump.color = 'violet'
        @heffalump.save
        heffalump_model.get(*@heffalump.key).color.should == 'violet'
      end

      it 'should not alter other fields' do
        color = @heffalump.color
        @heffalump.num_spots = 3
        @heffalump.save
        heffalump_model.get(*@heffalump.key).color.should == color
      end
    end
  else
    it 'needs to support #update'
  end

  if adapter_supports?(:delete)
    describe '#delete' do
      before do
        @heffalump = heffalump_model.create(:color => 'forest green')
      end

      after do
        heffalump_model.destroy
      end

      it 'should not raise any errors' do
        lambda {
          @heffalump.destroy
        }.should_not raise_error
      end

      it 'should delete the requested resource' do
        id = @heffalump.id
        @heffalump.destroy
        heffalump_model.get(id).should be_nil
      end
    end
  else
    it 'needs to support #delete'
  end

  if adapter_supports?(:read, :create)
    describe 'query matching' do
      before :all do
        @red  = heffalump_model.create(:color => 'red')
        @two  = heffalump_model.create(:num_spots => 2)
        @five = heffalump_model.create(:num_spots => 5)
      end

      after :all do
        heffalump_model.destroy
      end

      describe 'conditions' do
        describe 'eql' do
          it 'should be able to search for objects included in an inclusive range of values' do
            heffalump_model.all(:num_spots => 1..5).should include(@five)
          end

          it 'should be able to search for objects included in an exclusive range of values' do
            heffalump_model.all(:num_spots => 1...6).should include(@five)
          end

          it 'should not be able to search for values not included in an inclusive range of values' do
            heffalump_model.all(:num_spots => 1..4).should_not include(@five)
          end

          it 'should not be able to search for values not included in an exclusive range of values' do
            heffalump_model.all(:num_spots => 1...5).should_not include(@five)
          end
        end

        describe 'not' do
          it 'should be able to search for objects with not equal value' do
            heffalump_model.all(:color.not => 'red').should_not include(@red)
          end

          it 'should include objects that are not like the value' do
            heffalump_model.all(:color.not => 'black').should include(@red)
          end

          it 'should be able to search for objects with not nil value' do
            heffalump_model.all(:color.not => nil).should include(@red)
          end

          it 'should not include objects with a nil value' do
            heffalump_model.all(:color.not => nil).should_not include(@two)
          end

          it 'should be able to search for object with a nil value using required properties' do
            heffalump_model.all(:id.not => nil).should == [ @red, @two, @five ]
          end

          it 'should be able to search for objects not in an empty list (match all)' do
            heffalump_model.all(:color.not => []).should == [ @red, @two, @five ]
          end

          it 'should be able to search for objects in an empty list and another OR condition (match none on the empty list)' do
            heffalump_model.all(
              :conditions => DataMapper::Query::Conditions::Operation.new(
                :or,
                DataMapper::Query::Conditions::Comparison.new(:in, heffalump_model.properties[:color], []),
                DataMapper::Query::Conditions::Comparison.new(:in, heffalump_model.properties[:num_spots], [5])
              )
            ).should == [ @five ]
          end

          it 'should be able to search for objects not included in an array of values' do
            heffalump_model.all(:num_spots.not => [ 1, 3, 5, 7 ]).should include(@two)
          end

          it 'should be able to search for objects not included in an array of values' do
            heffalump_model.all(:num_spots.not => [ 1, 3, 5, 7 ]).should_not include(@five)
          end

          it 'should be able to search for objects not included in an inclusive range of values' do
            heffalump_model.all(:num_spots.not => 1..4).should include(@five)
          end

          it 'should be able to search for objects not included in an exclusive range of values' do
            heffalump_model.all(:num_spots.not => 1...5).should include(@five)
          end

          it 'should not be able to search for values not included in an inclusive range of values' do
            heffalump_model.all(:num_spots.not => 1..5).should_not include(@five)
          end

          it 'should not be able to search for values not included in an exclusive range of values' do
            heffalump_model.all(:num_spots.not => 1...6).should_not include(@five)
          end
        end

        describe 'like' do
          it 'should be able to search for objects that match value' do
            heffalump_model.all(:color.like => '%ed').should include(@red)
          end

          it 'should not search for objects that do not match the value' do
            heffalump_model.all(:color.like => '%blak%').should_not include(@red)
          end
        end

        describe 'regexp' do
          before do
            if (defined?(DataMapper::Adapters::SqliteAdapter) && adapter.kind_of?(DataMapper::Adapters::SqliteAdapter) ||
                defined?(DataMapper::Adapters::SqlserverAdapter) && adapter.kind_of?(DataMapper::Adapters::SqlserverAdapter))
              pending 'delegate regexp matches to same system that the InMemory and YAML adapters use'
            end
          end

          it 'should be able to search for objects that match value' do
            heffalump_model.all(:color => /ed/).should include(@red)
          end

          it 'should not be able to search for objects that do not match the value' do
            heffalump_model.all(:color => /blak/).should_not include(@red)
          end

          it 'should be able to do a negated search for objects that match value' do
            heffalump_model.all(:color.not => /blak/).should include(@red)
          end

          it 'should not be able to do a negated search for objects that do not match value' do
            heffalump_model.all(:color.not => /ed/).should_not include(@red)
          end

        end

        describe 'gt' do
          it 'should be able to search for objects with value greater than' do
            heffalump_model.all(:num_spots.gt => 1).should include(@two)
          end

          it 'should not find objects with a value less than' do
            heffalump_model.all(:num_spots.gt => 3).should_not include(@two)
          end
        end

        describe 'gte' do
          it 'should be able to search for objects with value greater than' do
            heffalump_model.all(:num_spots.gte => 1).should include(@two)
          end

          it 'should be able to search for objects with values equal to' do
            heffalump_model.all(:num_spots.gte => 2).should include(@two)
          end

          it 'should not find objects with a value less than' do
            heffalump_model.all(:num_spots.gte => 3).should_not include(@two)
          end
        end

        describe 'lt' do
          it 'should be able to search for objects with value less than' do
            heffalump_model.all(:num_spots.lt => 3).should include(@two)
          end

          it 'should not find objects with a value less than' do
            heffalump_model.all(:num_spots.gt => 2).should_not include(@two)
          end
        end

        describe 'lte' do
          it 'should be able to search for objects with value less than' do
            heffalump_model.all(:num_spots.lte => 3).should include(@two)
          end

          it 'should be able to search for objects with values equal to' do
            heffalump_model.all(:num_spots.lte => 2).should include(@two)
          end

          it 'should not find objects with a value less than' do
            heffalump_model.all(:num_spots.lte => 1).should_not include(@two)
          end
        end
      end

      describe 'limits' do
        it 'should be able to limit the objects' do
          heffalump_model.all(:limit => 2).length.should == 2
        end
      end
    end
  else
    it 'needs to support #read and #create to test query matching'
  end
end
