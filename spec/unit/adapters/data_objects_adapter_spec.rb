require 'monitor'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

require DataMapper.root / 'spec' / 'unit' / 'adapters' / 'adapter_shared_spec'

# TODO: make a shared adapter spec for all the DAO objects to adhere to

describe DataMapper::Adapters::DataObjectsAdapter do
  before :all do
    class Cheese
      include DataMapper::Resource
      property :id, Integer, :serial => true
      property :name, String, :nullable => false
      property :color, String, :default => 'yellow'
      property :notes, String, :length => 100, :lazy => true
    end
  end

  before do
    @uri     = Addressable::URI.parse('mock://localhost')
    @adapter = DataMapper::Adapters::DataObjectsAdapter.new(:default, @uri)
  end

  it_should_behave_like 'a DataMapper Adapter'

  describe "#find_by_sql" do

    before do
      class Plupp
        include DataMapper::Resource
        property :id, Integer, :key => true
        property :name, String
      end
    end

    it "should be added to DataMapper::Resource::ClassMethods" do
      DataMapper::Resource::ClassMethods.instance_methods.include?("find_by_sql").should == true
      Plupp.should respond_to(:find_by_sql)
    end

    describe "when called" do

      before do
        @reader = mock("reader")
        @reader.stub!(:next!).and_return(false)
        @reader.stub!(:close)
        @connection = mock("connection")
        @connection.stub!(:close)
        @command = mock("command")
        @adapter = Plupp.repository.adapter
        @repository = Plupp.repository
        @repository.stub!(:adapter).and_return(@adapter)
        @adapter.stub!(:create_connection).and_return(@connection)
        @adapter.should_receive(:is_a?).any_number_of_times.with(DataMapper::Adapters::DataObjectsAdapter).and_return(true)
      end

      it "should accept a single String argument with or without options hash" do
        @connection.should_receive(:create_command).twice.with("SELECT * FROM plupps").and_return(@command)
        @command.should_receive(:set_types).twice.with([Integer, String])
        @command.should_receive(:execute_reader).twice.and_return(@reader)
        Plupp.should_receive(:repository).any_number_of_times.and_return(@repository)
        Plupp.should_receive(:repository).any_number_of_times.with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql("SELECT * FROM plupps").to_a
        Plupp.find_by_sql("SELECT * FROM plupps", :repository => :plupp_repo).to_a
      end

      it "should accept an Array argument with or without options hash" do
        @connection.should_receive(:create_command).twice.with("SELECT * FROM plupps WHERE plur = ?").and_return(@command)
        @command.should_receive(:set_types).twice.with([Integer, String])
        @command.should_receive(:execute_reader).twice.with("my pretty plur").and_return(@reader)
        Plupp.should_receive(:repository).any_number_of_times.and_return(@repository)
        Plupp.should_receive(:repository).any_number_of_times.with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql(["SELECT * FROM plupps WHERE plur = ?", "my pretty plur"]).to_a
        Plupp.find_by_sql(["SELECT * FROM plupps WHERE plur = ?", "my pretty plur"], :repository => :plupp_repo).to_a
      end

      it "should accept a Query argument with or without options hash" do
        @connection.should_receive(:create_command).twice.with("SELECT \"name\" FROM \"plupps\" WHERE \"name\" = ?").and_return(@command)
        @command.should_receive(:set_types).twice.with([Integer, String])
        @command.should_receive(:execute_reader).twice.with(Plupp.properties[:name]).and_return(@reader)
        Plupp.should_receive(:repository).any_number_of_times.and_return(@repository)
        Plupp.should_receive(:repository).any_number_of_times.with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql(DataMapper::Query.new(@repository, Plupp, "name" => "my pretty plur", :fields => ["name"])).to_a
        Plupp.find_by_sql(DataMapper::Query.new(@repository, Plupp, "name" => "my pretty plur", :fields => ["name"]), :repository => :plupp_repo).to_a
      end

      it "requires a Repository that is a DataObjectsRepository to work" do
        non_do_adapter = mock("non do adapter")
        non_do_repo = mock("non do repo")
        non_do_repo.stub!(:adapter).and_return(non_do_adapter)
        Plupp.should_receive(:repository).any_number_of_times.with(:plupp_repo).and_return(non_do_repo)
        Proc.new do
          Plupp.find_by_sql(:repository => :plupp_repo)
        end.should raise_error(Exception, /DataObjectsAdapter/)
      end

      it "requires some kind of query to work at all" do
        Plupp.should_receive(:repository).any_number_of_times.with(:plupp_repo).and_return(@repository)
        Proc.new do
          Plupp.find_by_sql(:repository => :plupp_repo)
        end.should raise_error(Exception, /requires a query/)
      end

    end

  end

  describe '#uri options' do
    it 'should transform a fully specified option hash into a URI' do
      options = {
        :adapter => 'mysql',
        :host => 'davidleal.com',
        :username => 'me',
        :password => 'mypass',
        :port => 5000,
        :database => 'you_can_call_me_al',
        :socket => 'nosock'
      }

      adapter = DataMapper::Adapters::DataObjectsAdapter.new(:spec, options)
      adapter.uri.should ==
        Addressable::URI.parse("mysql://me:mypass@davidleal.com:5000/you_can_call_me_al?socket=nosock")
    end

    it 'should transform a minimal options hash into a URI' do
      options = {
        :adapter => 'mysql',
        :database => 'you_can_call_me_al'
      }

      adapter = DataMapper::Adapters::DataObjectsAdapter.new(:spec, options)
      adapter.uri.should == Addressable::URI.parse("mysql:///you_can_call_me_al")
    end

    it 'should accept the uri when no overrides exist' do
      uri = Addressable::URI.parse("protocol:///")
      DataMapper::Adapters::DataObjectsAdapter.new(:spec, uri).uri.should == uri
    end
  end

  describe '#create' do
    before do
      @result = mock('result', :to_i => 1, :insert_id => 1)

      @adapter.stub!(:execute).and_return(@result)

      @property   = mock('property', :field => 'property', :instance_variable_name => '@property', :serial? => false)
      @repository = mock('repository')
      @model      = mock('model', :storage_name => 'models', :key => [ @property ])
      @resource   = mock('resource', :class => @model, :dirty_attributes => [ @property ], :instance_variable_get => 'bind value')
    end

    it 'should use only dirty properties' do
      @resource.should_receive(:dirty_attributes).with(no_args).and_return([ @property ])
      @adapter.create(@repository, @resource)
    end

    it 'should use the properties field accessors' do
      @property.should_receive(:field).with(:default).and_return('property')
      @adapter.create(@repository, @resource)
    end

    it 'should use the bind values' do
      @property.should_receive(:instance_variable_name).with(no_args).and_return('@property')
      @resource.should_receive(:instance_variable_get).with('@property').and_return('bind value')
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when supports_returning? is false' do
      statement = 'INSERT INTO "models" ("property") VALUES (?)'
      @adapter.should_receive(:supports_returning?).with(no_args).and_return(false)
      @adapter.should_receive(:execute).with(statement, 'bind value').and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when supports_returning? is true' do
      statement = 'INSERT INTO "models" ("property") VALUES (?) RETURNING "property"'
      @property.should_receive(:serial?).with(no_args).and_return(true)
      @adapter.should_receive(:supports_returning?).with(no_args).and_return(true)
      @adapter.should_receive(:execute).with(statement, 'bind value').and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when supports_default_values? is true' do
      statement = 'INSERT INTO "models" DEFAULT VALUES'
      @resource.should_receive(:dirty_attributes).with(no_args).and_return([])
      @adapter.should_receive(:supports_default_values?).with(no_args).and_return(true)
      @adapter.should_receive(:execute).with(statement).and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when supports_default_values? is false' do
      statement = 'INSERT INTO "models" () VALUES ()'
      @resource.should_receive(:dirty_attributes).with(no_args).and_return([])
      @adapter.should_receive(:supports_default_values?).with(no_args).and_return(false)
      @adapter.should_receive(:execute).with(statement).and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should return false if number of rows created is 0' do
      @result.should_receive(:to_i).with(no_args).and_return(0)
      @adapter.create(@repository, @resource).should be_false
    end

    it 'should return true if number of rows created is 1' do
      @result.should_receive(:to_i).with(no_args).and_return(1)
      @adapter.create(@repository, @resource).should be_true
    end

    it 'should set the resource primary key if the model key size is 1 and the key is serial' do
      @model.key.size.should == 1
      @property.should_receive(:serial?).and_return(true)
      @result.should_receive(:insert_id).and_return(111)
      @resource.should_receive(:instance_variable_set).with('@property', 111)
      @adapter.create(@repository, @resource)
    end
  end

  describe '#read' do
    before do
      @primitive  = mock('primitive')
      @property   = mock('property', :field => 'property', :primitive => @primitive)
      @properties = mock('properties', :defaults => [ @property ])
      @repository = mock('repository', :kind_of? => true, :name => ADAPTER)
      @model      = mock('model', :properties => @properties, :< => true, :inheritance_property => nil, :key => [ @property ], :storage_name => 'models', :kind_of? => true)
      @key        = mock('key')
      @resource   = mock('resource')
      @query      = mock('query', :repository => @repository, :model => @model)
      @collection = mock('collection', :first => @resource, :query => @query)

      @reader     = mock('reader', :close => true, :next! => false)
      @command    = mock('command', :set_types => nil, :execute_reader => @reader)
      @connection = mock('connection', :close => true, :create_command => @command)

      DataObjects::Connection.stub!(:new).and_return(@connection)
      DataMapper::Collection.stub!(:new).and_return(@collection)
      DataMapper::Resource.stub!(:>).and_return(true)
      DataMapper::Property.stub!(:===).and_return(true)
    end

    it 'should lookup the model properties with the repository' do
      pending("DataObjectsAdapter#read is deprecated")
      @model.should_receive(:properties).with(:default).and_return(@properties)
      @adapter.read(@repository, @model, @key)
    end

    it 'should use the model default properties' do
      pending("DataObjectsAdapter#read is deprecated")
      @properties.should_receive(:defaults).any_number_of_times.with(no_args).and_return([ @property ])
      @adapter.read(@repository, @model, @key)
    end

    it 'should create a collection under the hood for retrieving the resource' do
      pending("DataObjectsAdapter#read is deprecated")
      DataMapper::Collection.should_receive(:new).with(@query, { @property => 0 }).and_return(@collection)
      @reader.should_receive(:next!).and_return(true)
      @reader.should_receive(:values).with(no_args).and_return({ :property => 'value' })
      @collection.should_receive(:load).with({ :property => 'value' })
      @collection.should_receive(:first).with(no_args).and_return(@resource)
      @adapter.read(@repository, @model, @key).should == @resource
    end

    it 'should use the bind values' do
      pending("DataObjectsAdapter#read is deprecated")
      @command.should_receive(:execute_reader).with(@key).and_return(@reader)
      @adapter.read(@repository, @model, @key)
    end

    it 'should generate an SQL statement' do
      pending("DataObjectsAdapter#read is deprecated")
      statement = 'SELECT "property" FROM "models" WHERE "property" = ? LIMIT 1'
      @model.should_receive(:key).any_number_of_times.with(:default).and_return([ @property ])
      @connection.should_receive(:create_command).with(statement).and_return(@command)
      @adapter.read(@repository, @model, @key)
    end

    it 'should generate an SQL statement with composite keys' do
      pending("DataObjectsAdapter#read is deprecated")
      other_property = mock('other property')
      other_property.should_receive(:field).with(:default).and_return('other')

      @model.should_receive(:key).any_number_of_times.with(:default).and_return([ @property, other_property ])

      statement = 'SELECT "property" FROM "models" WHERE "property" = ? AND "other" = ? LIMIT 1'
      @connection.should_receive(:create_command).with(statement).and_return(@command)

      @adapter.read(@repository, @model, @key)
    end

    it 'should set the return types to the property primitives' do
      pending("DataObjectsAdapter#read is deprecated")
      @command.should_receive(:set_types).with([ @primitive ])
      @adapter.read(@repository, @model, @key)
    end

    it 'should close the reader' do
      pending("DataObjectsAdapter#read is deprecated")
      @reader.should_receive(:close).with(no_args)
      @adapter.read(@repository, @model, @key)
    end

    it 'should close the connection' do
      pending("DataObjectsAdapter#read is deprecated")
      @connection.should_receive(:close).with(no_args)
      @adapter.read(@repository, @model, @key)
    end
  end

  describe '#update' do
    before do
      @result = mock('result', :to_i => 1)

      @adapter.stub!(:execute).and_return(@result)

      @property = mock('property', :field => 'property', :instance_variable_name => '@property', :serial? => false)
      @model    = mock('model', :storage_name => 'models', :key => [ @property ])
      @resource = mock('resource', :class => @model, :dirty_attributes => [ @property ], :instance_variable_get => 'bind value')
    end

    it 'should use only dirty properties' do
      @resource.should_receive(:dirty_attributes).with(no_args).and_return([ @property ])
      @adapter.update(@repository, @resource)
    end

    it 'should use the properties field accessors' do
      @property.should_receive(:field).with(:default).twice.and_return('property')
      @adapter.update(@repository, @resource)
    end

    it 'should use the bind values' do
      @property.should_receive(:instance_variable_name).with(no_args).twice.and_return('@property')
      @resource.should_receive(:instance_variable_get).with('@property').twice.and_return('bind value')
      @model.should_receive(:key).with(:default).and_return([ @property ])
      @adapter.should_receive(:execute).with(anything, 'bind value', 'bind value').and_return(@result)
      @adapter.update(@repository, @resource)
    end

    it 'should generate an SQL statement' do
      statement = 'UPDATE "models" SET "property" = ? WHERE "property" = ?'
      @adapter.should_receive(:execute).with(statement, anything, anything).and_return(@result)
      @adapter.update(@repository, @resource)
    end

    it 'should generate an SQL statement with composite keys' do
      other_property = mock('other property', :instance_variable_name => '@other')
      other_property.should_receive(:field).with(:default).and_return('other')

      @model.should_receive(:key).with(:default).and_return([ @property, other_property ])

      statement = 'UPDATE "models" SET "property" = ? WHERE "property" = ? AND "other" = ?'
      @adapter.should_receive(:execute).with(statement, anything, anything, anything).and_return(@result)

      @adapter.update(@repository, @resource)
    end

    it 'should return false if number of rows updated is 0' do
      @result.should_receive(:to_i).with(no_args).and_return(0)
      @adapter.update(@repository, @resource).should be_false
    end

    it 'should return true if number of rows updated is 1' do
      @result.should_receive(:to_i).with(no_args).and_return(1)
      @adapter.update(@repository, @resource).should be_true
    end

    it 'should not try to update if there are no dirty attributes' do
      @resource.should_receive(:dirty_attributes).with(no_args).and_return([])
      @adapter.update(@repository, @resource).should be_false
    end
  end

  describe '#delete' do
    before do
      @result = mock('result', :to_i => 1)

      @adapter.stub!(:execute).and_return(@result)

      @property   = mock('property', :instance_variable_name => '@property', :field => 'property')
      @repository = mock('repository')
      @model      = mock('model', :storage_name => 'models', :key => [ @property ])
      @resource   = mock('resource', :class => @model, :instance_variable_get => 'bind value')
    end

    it 'should use the properties field accessors' do
      @property.should_receive(:field).with(:default).and_return('property')
      @adapter.delete(@repository, @resource)
    end

    it 'should use the bind values' do
      @property.should_receive(:instance_variable_name).with(no_args).and_return('@property')
      @resource.should_receive(:instance_variable_get).with('@property').and_return('bind value')

      @model.should_receive(:key).with(:default).and_return([ @property ])

      @adapter.should_receive(:execute).with(anything, 'bind value').and_return(@result)

      @adapter.delete(@repository, @resource)
    end

    it 'should generate an SQL statement' do
      statement = 'DELETE FROM "models" WHERE "property" = ?'
      @adapter.should_receive(:execute).with(statement, anything).and_return(@result)
      @adapter.delete(@repository, @resource)
    end

    it 'should generate an SQL statement with composite keys' do
      other_property = mock('other property', :instance_variable_name => '@other')
      other_property.should_receive(:field).with(:default).and_return('other')

      @model.should_receive(:key).with(:default).and_return([ @property, other_property ])

      statement = 'DELETE FROM "models" WHERE "property" = ? AND "other" = ?'
      @adapter.should_receive(:execute).with(statement, anything, anything).and_return(@result)

      @adapter.delete(@repository, @resource)
    end

    it 'should return false if number of rows deleted is 0' do
      @result.should_receive(:to_i).with(no_args).and_return(0)
      @adapter.delete(@repository, @resource).should be_false
    end

    it 'should return true if number of rows deleted is 1' do
      @result.should_receive(:to_i).with(no_args).and_return(1)
      @adapter.delete(@repository, @resource).should be_true
    end
  end

  describe '#read_set' do
    it 'needs specs'
  end

  describe "when upgrading tables" do
    it "should raise NotImplementedError when #storage_exists? is called" do
      lambda { @adapter.storage_exists?("cheeses") }.should raise_error(NotImplementedError)
    end

    describe "#upgrade_model_storage" do
      it "should call #create_model_storage" do
        @adapter.should_receive(:create_model_storage).with(nil, Cheese).and_return(true)
        @adapter.upgrade_model_storage(nil, Cheese).should == Cheese.properties
      end

      it "should check if all properties of the model have columns if the table exists" do
        @adapter.should_receive(:field_exists?).with("cheeses", "id").and_return(true)
        @adapter.should_receive(:field_exists?).with("cheeses", "name").and_return(true)
        @adapter.should_receive(:field_exists?).with("cheeses", "color").and_return(true)
        @adapter.should_receive(:field_exists?).with("cheeses", "notes").and_return(true)
        @adapter.should_receive(:storage_exists?).with("cheeses").and_return(true)
        @adapter.upgrade_model_storage(nil, Cheese).should == []
      end

      it "should create and execute add column statements for columns that dont exist" do
        @adapter.should_receive(:field_exists?).with("cheeses", "id").and_return(true)
        @adapter.should_receive(:field_exists?).with("cheeses", "name").and_return(true)
        @adapter.should_receive(:field_exists?).with("cheeses", "color").and_return(true)
        @adapter.should_receive(:field_exists?).with("cheeses", "notes").and_return(false)
        @adapter.should_receive(:storage_exists?).with("cheeses").and_return(true)
        connection = mock("connection")
        connection.should_receive(:close)
        @adapter.should_receive(:create_connection).and_return(connection)
        statement = mock("statement")
        command = mock("command")
        result = mock("result")
        result.should_receive(:to_i).and_return(1)
        command.should_receive(:execute_non_query).and_return(result)
        connection.should_receive(:create_command).with(statement).and_return(command)
        @adapter.should_receive(:alter_table_add_column_statement).with("cheeses",
                                                                             {
                                                                               :nullable? => true,
                                                                               :name => "notes",
                                                                               :serial? => false,
                                                                               :primitive => "VARCHAR",
                                                                               :size => 100
                                                                             }).and_return(statement)
        @adapter.upgrade_model_storage(nil, Cheese).should == [Cheese.notes]
      end
    end
  end

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
      @mock_command.should_receive(:execute_non_query).and_raise("Oh Noes!")
      DataMapper.logger.should_receive(:error)

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
      @mock_command.should_receive(:execute_non_query).and_raise("Oh Noes!")
      DataMapper.logger.should_receive(:error)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end

    it 'should always close the db connection' do
      @mock_command.should_receive(:execute_non_query).and_raise("Oh Noes!")
      @mock_db.should_receive(:close)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end
  end
end
