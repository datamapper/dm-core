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
        @command.should_receive(:set_types).twice.with([Fixnum, String])
        @command.should_receive(:execute_reader).twice.and_return(@reader)
        Plupp.should_receive(:repository).any_number_of_times.and_return(@repository)
        Plupp.should_receive(:repository).any_number_of_times.with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql("SELECT * FROM plupps").to_a
        Plupp.find_by_sql("SELECT * FROM plupps", :repository => :plupp_repo).to_a
      end

      it "should accept an Array argument with or without options hash" do
        @connection.should_receive(:create_command).twice.with("SELECT * FROM plupps WHERE plur = ?").and_return(@command)
        @command.should_receive(:set_types).twice.with([Fixnum, String])
        @command.should_receive(:execute_reader).twice.with("my pretty plur").and_return(@reader)
        Plupp.should_receive(:repository).any_number_of_times.and_return(@repository)
        Plupp.should_receive(:repository).any_number_of_times.with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql(["SELECT * FROM plupps WHERE plur = ?", "my pretty plur"]).to_a
        Plupp.find_by_sql(["SELECT * FROM plupps WHERE plur = ?", "my pretty plur"], :repository => :plupp_repo).to_a
      end

      it "should accept a Query argument with or without options hash" do
        @connection.should_receive(:create_command).twice.with("SELECT \"name\" FROM \"plupps\" WHERE \"name\" = ?").and_return(@command)
        @command.should_receive(:set_types).twice.with([Fixnum, String])
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
      @result = mock('result', :to_i => 1)

      @adapter.stub!(:execute).and_return(@result)

      @property   = mock('property', :field => 'property', :instance_variable_name => '@property', :serial? => false)
      @repository = mock('repository')
      @model      = mock('model', :storage_name => 'models', :key => [ @property ])
      @resource   = mock('resource', :class => @model, :dirty_attributes => [ @property ], :instance_variable_get => 'bind value')
    end

    it 'should use only dirty properties' do
      @resource.should_receive(:dirty_attributes).with(no_args).once.and_return([ @property ])
      @adapter.create(@repository, @resource)
    end

    it 'should use the properties field accessors' do
      @property.should_receive(:field).with(no_args).once.and_return('property')
      @adapter.create(@repository, @resource)
    end

    it 'should get the bind values' do
      @property.should_receive(:instance_variable_name).with(no_args).once.and_return('@property')
      @resource.should_receive(:instance_variable_get).with('@property').once.and_return('bind value')
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when create_with_returning? is false' do
      statement = 'INSERT INTO "models" ("property") VALUES (?)'
      @adapter.should_receive(:create_with_returning?).with(no_args).and_return(false)
      @adapter.should_receive(:execute).with(statement, 'bind value').once.and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when create_with_returning? is true' do
      statement = 'INSERT INTO "models" ("property") VALUES (?) RETURNING "property"'
      @adapter.should_receive(:create_with_returning?).with(no_args).and_return(true)
      @adapter.should_receive(:execute).with(statement, 'bind value').once.and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should return false if number of rows created is 0' do
      @result.should_receive(:to_i).with(no_args).once.and_return(0)
      @adapter.create(@repository, @resource).should be_false
    end

    it 'should return true if number of rows created is 1' do
      @result.should_receive(:to_i).with(no_args).once.and_return(1)
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
    it 'needs specs'

    #  describe "#read_statement (without lazy attributes)" do
    #    it 'should generate a SQL statement for a serial Key' do
    #      @adapter.read_statement(Cheese, [1]).should == <<-EOS.compress_lines
    #        SELECT "id", "name", "color" FROM "cheeses" WHERE "id" = ?
    #      EOS
    #    end
    #
    #    it "should generate a SQL statement that includes a Composite Key" do
    #      @adapter.read_statement(LittleBox, ['Shady Drive', 'Blue']).should == <<-EOS.compress_lines
    #        SELECT "street", "color", "hillside" FROM "little_boxes" WHERE "street" = ? AND "color" = ?
    #      EOS
    #    end
    #  end
  end

  describe '#update' do
    it 'needs specs'

    it 'should not try to update if there are no dirty attributes' do
      repository = mock("repository")
      resource = mock("resource")
      resource.stub!(:dirty_attributes).and_return({})
      @adapter.update(repository, resource).should == false
    end

    #  describe "#update_statement" do
    #
    #    it 'should generate a SQL statement for all fields' do
    #      @adapter.update_statement(Cheese, Cheese.properties(@adapter.name).slice(:name, :color)).should == <<-EOS.compress_lines
    #        UPDATE "cheeses" SET
    #        "name" = ?,
    #        "color" = ?
    #        WHERE "id" = ?
    #      EOS
    #    end
    #
    #    it "should generate a SQL statement for only dirty fields" do
    #      @adapter.update_statement(Cheese, Cheese.properties(@adapter.name).slice(:name)).should == <<-EOS.compress_lines
    #        UPDATE "cheeses" SET "name" = ? WHERE "id" = ?
    #      EOS
    #
    #      @adapter.update_statement(Cheese, Cheese.properties(@adapter.name).slice(:color)).should == <<-EOS.compress_lines
    #        UPDATE "cheeses" SET "color" = ? WHERE "id" = ?
    #      EOS
    #    end
    #
    #    it "should generate a SQL statement that includes a Composite Key" do
    #      @adapter.update_statement(LittleBox, LittleBox.properties(@adapter.name).slice(:hillside)).should == <<-EOS.compress_lines
    #        UPDATE "little_boxes" SET "hillside" = ? WHERE "street" = ? AND "color" = ?
    #      EOS
    #
    #      @adapter.update_statement(LittleBox, LittleBox.properties(@adapter.name).slice(:color, :hillside)).should == <<-EOS.compress_lines
    #        UPDATE "little_boxes" SET "color" = ?, "hillside" = ? WHERE "street" = ? AND "color" = ?
    #      EOS
    #    end
    #
    #  end
  end

  describe '#delete' do
    it 'needs specs'

    #  describe "#delete_statement" do
    #
    #    it 'should generate a SQL statement for a serial Key' do
    #      @adapter.delete_statement(Cheese).should == <<-EOS.compress_lines
    #        DELETE FROM "cheeses" WHERE "id" = ?
    #      EOS
    #    end
    #
    #    it "should generate a SQL statement for a Composite Key" do
    #      @adapter.delete_statement(LittleBox).should == <<-EOS.compress_lines
    #        DELETE FROM "little_boxes" WHERE "street" = ? AND "color" = ?
    #      EOS
    #    end
    #
    #  end
  end

  describe '#read_set' do
    it 'needs specs'
  end

  describe "when upgrading tables" do
    it "should raise NotImplementedError when #exists? is called" do
      lambda { @adapter.exists?("cheeses") }.should raise_error(NotImplementedError)
    end

    describe "#upgrade_model_storage" do
      it "should call #create_model_storage unless the model storage alread exists" do
        @adapter.should_receive(:exists?).once.with("cheeses").and_return(false)
        @adapter.should_receive(:create_model_storage).once.with(nil, Cheese).and_return(true)
        @adapter.upgrade_model_storage(nil, Cheese).should == Cheese
      end

      it "should check if all properties of the model have columns if the table exists" do
        @adapter.should_receive(:field_exists?).once.with("cheeses", "id").and_return(true)
        @adapter.should_receive(:field_exists?).once.with("cheeses", "name").and_return(true)
        @adapter.should_receive(:field_exists?).once.with("cheeses", "color").and_return(true)
        @adapter.should_receive(:field_exists?).once.with("cheeses", "notes").and_return(true)
        @adapter.should_receive(:exists?).once.with("cheeses").and_return(true)
        connection = mock("connection")
        connection.should_receive(:close).once
        @adapter.should_receive(:create_connection).once.and_return(connection)
        @adapter.upgrade_model_storage(nil, Cheese).should == []
      end

      it "should create and execute add column statements for columns that dont exist" do
        @adapter.should_receive(:field_exists?).once.with("cheeses", "id").and_return(true)
        @adapter.should_receive(:field_exists?).once.with("cheeses", "name").and_return(true)
        @adapter.should_receive(:field_exists?).once.with("cheeses", "color").and_return(true)
        @adapter.should_receive(:field_exists?).once.with("cheeses", "notes").and_return(false)
        @adapter.should_receive(:exists?).once.with("cheeses").and_return(true)
        connection = mock("connection")
        connection.should_receive(:close).once
        @adapter.should_receive(:create_connection).once.and_return(connection)
        statement = mock("statement")
        command = mock("command")
        result = mock("result")
        result.should_receive(:to_i).once.and_return(1)
        command.should_receive(:execute_non_query).once.and_return(result)
        connection.should_receive(:create_command).once.with(statement).and_return(command)
        @adapter.should_receive(:alter_table_add_column_statement).once.with("cheeses",
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
