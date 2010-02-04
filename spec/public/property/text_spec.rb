require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Property, 'Text type' do
  describe 'migration with an index' do
    supported_by :all do
      before do
        @model = DataMapper::Model.new do
          storage_names[:default] = 'anonymous'

          property :id,   DataMapper::Types::Serial
          property :body, DataMapper::Types::Text, :index => true
        end
      end

      it 'should allow a migration' do
        lambda {
          @model.auto_migrate!
        }.should_not raise_error(DataObjects::SyntaxError)
      end
    end
  end if defined?(DataObjects::SyntaxError)

  describe 'migration with a unique index' do
    supported_by :all do
      before do
        @model = DataMapper::Model.new do
          storage_names[:default] = 'anonymous'

          property :id,   DataMapper::Types::Serial
          property :body, DataMapper::Types::Text, :unique_index => true
        end
      end

      it 'should allow a migration' do
        lambda {
          @model.auto_migrate!
        }.should_not raise_error(DataObjects::SyntaxError)
      end
    end
  end if defined?(DataObjects::SyntaxError)
end
