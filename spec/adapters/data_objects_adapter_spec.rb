require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require __DIR__.parent.parent + 'lib/data_mapper'
require __DIR__.parent.parent + 'lib/data_mapper/adapters/data_objects_adapter'
require __DIR__.parent + 'adapter_sharedspec'

describe DataMapper::Adapters::DataObjectsAdapter do
  before do
    @adapter = DataMapper::Adapters::DataObjectsAdapter.new(:default, 'mock::/localhost')
  end

  it_should_behave_like 'a DataMapper Adapter'

  describe '#execute' do
    before do
      @mock_command = mock('Command', :execute_non_query => nil)
      @mock_db = mock('DB Connection', :create_command => @mock_command, :close => true)

      @adapter.stub!(:create_connection).and_return(@mock_db)
    end 

    it 'should #create_command from the sql passed' do
      @mock_db.should_receive(:create_command).with('SQL STRING').and_return(@mock_command)
      @adapter.execute('SQL STRING')
    end

    it 'should pass any additional args to #execute_non_query' do
      @mock_command.should_receive(:execute_non_query).with(:args)
      @adapter.execute('SQL STRING', :args)
    end

    it 'should return the result of #execute_non_query' do
      @mock_command.should_receive(:execute_non_query).and_return(:result_set)

      @adapter.execute('SQL STRING').should == :result_set
    end

    it 'should log any errors, then re-raise them' do
      pending
      @mock_command.should_receive(:execute_non_query).and_raise("Oh Noes!")
      #DataMapper.logger.should_receive(:error)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end

    it 'should always close the db connection' do
      @mock_command.should_receive(:execute_non_query).and_raise("Oh Noes!")
      @mock_db.should_receive(:close)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end
  end

  describe '#query' do
    before do
      @mock_reader = mock('Reader', :fields => ['id', 'UserName', 'AGE'], 
                                    :values => [1, 'rando', 27],
                                    :close => true)
      @mock_command = mock('Command', :execute_reader => @mock_reader)
      @mock_db = mock('DB Connection', :create_command => @mock_command, :close => true)

      #make the while loop run exactly once
      @mock_reader.stub!(:next!).and_return(true, nil)
      @adapter.stub!(:create_connection).and_return(@mock_db)
    end 

    it 'should #create_command from the sql passed' do
      @mock_db.should_receive(:create_command).with('SQL STRING').and_return(@mock_command)
      @adapter.query('SQL STRING')
    end

    it 'should pass any additional args to #execute_reader' do
      @mock_command.should_receive(:execute_reader).with(:args).and_return(@mock_reader)
      @adapter.query('SQL STRING', :args)
    end

    describe 'returning multiple fields' do

      it 'should underscore the field names as members of the result struct' do
        @mock_reader.should_receive(:fields).and_return(['id', 'UserName', 'AGE'])

        result = @adapter.query('SQL STRING')

        result.first.members.should == %w{id user_name age}
      end

      it 'should convert each row into the struct' do
        @mock_reader.should_receive(:values).and_return([1, 'rando', 27])

        @adapter.query('SQL STRING')
      end

      it 'should add the row structs into the results array' do
        results = @adapter.query('SQL STRING')

        results.should be_kind_of(Array)

        row = results.first
        row.should be_kind_of(Struct)

        row.id.should == 1
        row.user_name.should == 'rando'
        row.age.should == 27
      end

    end

    describe 'returning a single field' do

      it 'should add the value to the results array' do
        @mock_reader.should_receive(:fields).and_return(['username'])
        @mock_reader.should_receive(:values).and_return(['rando'])

        results = @adapter.query('SQL STRING')

        results.should be_kind_of(Array)
        results.first.should == 'rando'
      end

    end

    it 'should log any errors, then re-raise them' do
      pending
      @mock_command.should_receive(:execute_non_query).and_raise("Oh Noes!")
      #DataMapper.logger.should_receive(:error)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end

    it 'should always close the db connection' do
      @mock_command.should_receive(:execute_non_query).and_raise("Oh Noes!")
      @mock_db.should_receive(:close)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end
  end
end

describe DataMapper::Adapters::DataObjectsAdapter::SQL, "creating, reading, updating, deleting statements" do
  before do
    @adapter = DataMapper::Adapters::DataObjectsAdapter.new(:default, 'mock::/localhost')
    
    class Cheese
      include DataMapper::Resource
      property :id, Fixnum, :serial => true
      property :name, String
      property :color, String
    end
  end
  
  # @mock_db.should_receive(:create_command).with('SQL STRING').and_return(@mock_command)
  
  describe "#create_statement" do
    it 'should generate a SQL statement for all fields' do      
      cheese = Cheese.new
      cheese.name = 'Havarti'
      cheese.color = 'Ivory'
      
      @adapter.class::SQL.create_statement(@adapter, cheese).should eql <<-EOS.compress_lines
        INSERT INTO "cheeses" ("name", "color") VALUES (?, ?)
      EOS
    end
    
    it "should generate a SQL statement for only dirty fields" do      
      cheese = Cheese.new
      cheese.name = 'Cheddar'

      @adapter.class::SQL.create_statement(@adapter, cheese).should eql <<-EOS.compress_lines
        INSERT INTO "cheeses" ("name") VALUES (?)
      EOS
      
      cheese = Cheese.new
      cheese.color = 'Orange'

      @adapter.class::SQL.create_statement(@adapter, cheese).should eql <<-EOS.compress_lines
        INSERT INTO "cheeses" ("color") VALUES (?)
      EOS
    end
  end
  
  describe "#create_statement_with_returning" do
    it 'should generate SQL' do
      pending
      
      # def self.create_statement_with_returning(adapter, instance)
      #   properties = resource.properties(adapter.name)
      #   <<-EOS.compress_lines
      #     INSERT INTO #{adapter.quote_table_name(resource.resource_name(adapter.name))} (
      #       #{properties.map { |property| adapter.quote_column_name(property.field) }.join($/)}
      #     ) VALUES (
      #       #{(['?'] * properties.size).join(', ')}
      #     ) RETURNING #{adapter.quote_column_name(resource.key(adapter.name).first.field)}
      #   EOS
      # end
    end
  end
  
  describe "#update_statement" do
    it 'should generate SQL' do
      pending
      
      # def self.update_statement(adapter, instance)
      #   #these properties need to be dirty TODO
      #   properties = instance.class.properties(adapter.name)
      #   <<-EOS.compress_lines
      #     UPDATE #{adapter.quote_table_name(resource.resource_name(adapter.name))} 
      #     SET #{properties.map {|attribute| "#{adapter.quote_column_name(attribute.field)} = ?" }.join(', ')}
      #     WHERE #{resource.key(adapter.name).map { |key| "#{adapter.quote_column_name(key.field)} = ?" }.join(' AND ')}
      #   EOS
      # end
    end
  end
  
  describe "#delete_statement" do
    it 'should generate SQL' do
      pending
      
      # def self.delete_statement(adapter, instance)
      #   properties = resource.properties(adapter.name)
      #   <<-EOS.compress_lines
      #     DELETE FROM #{adapter.quote_table_name(resource.resource_name(adapter.name))} 
      #     WHERE #{resource.key(adapter.name).map { |key| "#{adapter.quote_column_name(key.field)} = ?" }.join(' AND ')}
      #   EOS
      # end
    end
  end
  
  describe "#read_statement" do
    
    it 'should generate SQL' do
      pending
      
      # def self.read_statement(adapter, resource)
      #   properties = resource.properties(adapter.name)
      #   <<-EOS.compress_lines
      #     SELECT #{properties.map { |property| adapter.quote_column_name(property.field) }.join(', ')} 
      #     FROM #{adapter.quote_table_name(resource.resource_name(adapter.name))} 
      #     WHERE #{resource.key(adapter.name).map { |key| "#{adapter.quote_column_name(key.field)} = ?" }.join(' AND ')}
      #   EOS
      # end
    end
  end
end
