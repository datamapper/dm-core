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
  end

  describe "DataMapper::Model with #{ADAPTER}" do
    before do
      repository(ADAPTER) do
        ModelSpec::STI.auto_migrate!
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
