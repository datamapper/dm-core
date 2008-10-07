require File.expand_path(File.join(File.dirname(__FILE__), '..', "..", 'spec_helper'))

describe DataMapper::Adapters::InMemoryAdapter do
  before do
    DataMapper.setup(:inmem, :adapter => 'in_memory')

    class Heffalump
      include DataMapper::Resource
      def self.default_repository_name
        :inmem
      end

      property :color,      String, :key => true # TODO: Drop the 'must have a key' limitation
      property :num_spots,  Integer
      property :striped,    Boolean
    end

    @heff1 = Heffalump.new(:color => 'Black',
                           :num_spots => 0,
                           :striped => true)
    @heff1.save
    @heff2 = Heffalump.new(:color => 'Brown',
                           :num_spots => 25,
                           :striped => false)
    @heff2.save
  end

  it 'should successfully save an object' do
    @heff1.new_record?.should be_false
  end

  it 'should be able to get the object' do
    Heffalump.get('Black').should == @heff1
  end

  it 'should be able to get all the objects' do
    Heffalump.all.should == [@heff1, @heff2]
  end

  it 'should be able to search for an object' do
    Heffalump.all(:striped => true).should == [@heff1]
  end

  describe '#boolean_and' do
    before do
      @adapter = DataMapper.repository(:inmem).adapter
    end

    it 'should be true when every element is true' do
      @adapter.boolean_and(true, true, true).should be_true
    end

    it 'should be false if any element is false' do
      @adapter.boolean_and(true, false, true).should be_false
    end

  end




end
