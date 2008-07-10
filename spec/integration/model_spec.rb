require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  module ModelSpec
    class STI
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id,   Serial
      property :name, String
      property :type, Discriminator
    end

    class STIDescendant < STI
    end
  end

  describe "DataMapper::Model with #{ADAPTER}" do
    before do
      repository(ADAPTER) do
        ModelSpec::STI.auto_migrate!
      end

      @planet = DataMapper::Model.new('planet') do
        def self.default_repository_name; ADAPTER end
        property :name, String, :key => true
        property :distance, Integer
      end

      @moon   = DataMapper::Model.new('moon') do
        def self.default_repository_name; ADAPTER end
        property :id, DM::Serial
        property :name, String
      end

      @planet.auto_migrate!(ADAPTER)
      @moon.auto_migrate!(ADAPTER)

      repository(ADAPTER) do
        @moon.create(:name => "Charon")
        @moon.create(:name => "Phobos")
      end
    end

    describe '.new' do
      it 'should be able to persist' do
        repository(ADAPTER) do
          pluto = @planet.new
          pluto.name = 'Pluto'
          pluto.distance = 1_000_000
          pluto.save

          clone = @planet.get!('Pluto')
          clone.name.should == 'Pluto'
          clone.distance.should == 1_000_000
        end
      end
    end

    describe ".get" do
      include LoggingHelper

      it "should typecast key" do
        resource = nil
        lambda {
          repository(ADAPTER) do
            resource = @moon.get("1")
          end
        }.should_not raise_error
        resource.should be_kind_of(DataMapper::Resource)
      end

      it "should use the identity map within a repository block" do
        logger do |log|
          repository(ADAPTER) do
            @moon.get("1")
            @moon.get(1)
          end
          log.readlines.size.should == 1
        end
      end

      it "should not use the identity map outside a repository block" do
        logger do |log|
          @moon.get(1)
          @moon.get(1)
          log.readlines.size.should == 2
        end
      end
    end

    describe ".base_model" do
      describe "(when called on base model)" do
        it "should refer to itself" do
          ModelSpec::STI.base_model.should == ModelSpec::STI
        end
      end
      describe "(when called on descendant model)" do
        it "should refer to the base model" do
          ModelSpec::STIDescendant.base_model.should == ModelSpec::STI.base_model
        end
      end
    end

    it 'should provide #load' do
      ModelSpec::STI.should respond_to(:load)
    end

    describe '#load' do
      it 'should load resources with nil discriminator fields' do
        resource = ModelSpec::STI.create(:name => 'resource')
        query = ModelSpec::STI.all.query
        fields = query.fields

        fields.should == ModelSpec::STI.properties(ADAPTER).slice(:id, :name, :type)

        # would blow up prior to fix
        lambda {
          ModelSpec::STI.load([ resource.id, resource.name, nil ], query)
        }.should_not raise_error(NoMethodError)
      end
    end
  end
end
