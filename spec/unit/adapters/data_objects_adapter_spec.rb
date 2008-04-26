require 'monitor'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

require DataMapper.root / 'spec' / 'unit' / 'adapters' / 'adapter_shared_spec'

describe DataMapper::Adapters::DataObjectsAdapter do
  before do
    @adapter = DataMapper::Adapters::DataObjectsAdapter.new(:default, URI.parse('mock://localhost'))
  end

  it_should_behave_like 'a DataMapper Adapter'

  describe "#find_by_sql" do

    before do
      class Plupp
        include DataMapper::Resource
        property :id, Fixnum, :key => true
        property :name, String
      end
    end

    it "should be added to DataMapper::Resource::ClassMethods" do
      DataMapper::Resource::ClassMethods.instance_methods.include?("find_by_sql").should == true
      Plupp.methods.include?("find_by_sql").should == true
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
        Plupp.find_by_sql("SELECT * FROM plupps")
        Plupp.find_by_sql("SELECT * FROM plupps", :repository => :plupp_repo)
      end
      
      it "should accept an Array argument with or without options hash" do
        @connection.should_receive(:create_command).twice.with("SELECT * FROM plupps WHERE plur = ?").and_return(@command)
        @command.should_receive(:set_types).twice.with([Fixnum, String])
        @command.should_receive(:execute_reader).twice.with("my pretty plur").and_return(@reader)
        Plupp.should_receive(:repository).any_number_of_times.and_return(@repository)
        Plupp.should_receive(:repository).any_number_of_times.with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql(["SELECT * FROM plupps WHERE plur = ?", "my pretty plur"])
        Plupp.find_by_sql(["SELECT * FROM plupps WHERE plur = ?", "my pretty plur"], :repository => :plupp_repo)
      end
      
      it "should accept a Query argument with or without options hash" do
        @connection.should_receive(:create_command).twice.with("SELECT \"name\" FROM \"plupps\" WHERE (\"name\" = ?)").and_return(@command)
        @command.should_receive(:set_types).twice.with([Fixnum, String])
        @command.should_receive(:execute_reader).twice.with(Plupp.properties[:name]).and_return(@reader)
        Plupp.should_receive(:repository).any_number_of_times.and_return(@repository)
        Plupp.should_receive(:repository).any_number_of_times.with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql(DataMapper::Query.new(@repository, Plupp, "name" => "my pretty plur", :fields => ["name"]))
        Plupp.find_by_sql(DataMapper::Query.new(@repository, Plupp, "name" => "my pretty plur", :fields => ["name"]), :repository => :plupp_repo)
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
    @adapter = DataMapper::Adapters::DataObjectsAdapter.new(:default, URI.parse('mock://localhost'))

    class Cheese
      include DataMapper::Resource
      property :id, Fixnum, :serial => true
      property :name, String
      property :color, String
      property :notes, String, :lazy => true
    end

    class LittleBox
      include DataMapper::Resource
      property :street, String, :key => true
      property :color, String, :key => true
      property :hillside, TrueClass, :default => true
      property :notes, String, :lazy => true
    end
  end

  describe "#create_statement" do
    it 'should generate a SQL statement for all fields' do
      @adapter.create_statement(Cheese, Cheese.properties(@adapter.name).slice(:name, :color)).should == <<-EOS.compress_lines
        INSERT INTO "cheeses" ("name", "color") VALUES (?, ?)
      EOS
    end

    it "should generate a SQL statement for only dirty fields" do
      @adapter.create_statement(Cheese, Cheese.properties(@adapter.name).slice(:name)).should == <<-EOS.compress_lines
        INSERT INTO "cheeses" ("name") VALUES (?)
      EOS

      @adapter.create_statement(Cheese, Cheese.properties(@adapter.name).slice(:color)).should == <<-EOS.compress_lines
        INSERT INTO "cheeses" ("color") VALUES (?)
      EOS
    end
  end

  describe "#update" do
    it 'should not try to update if there are no dirty attributes' do
      repository = mock("repository")
      resource = mock("resource")
      resource.stub!(:dirty_attributes).and_return({})
      @adapter.update(repository, resource).should == false
    end
  end

  describe "#create_statement_with_returning" do

    it 'should generate a SQL statement for all fields' do
      @adapter.create_statement_with_returning(Cheese, Cheese.properties(@adapter.name).slice(:name, :color)).should == <<-EOS.compress_lines
        INSERT INTO "cheeses" ("name", "color") VALUES (?, ?) RETURNING "id"
      EOS
    end

    it "should generate a SQL statement for only dirty fields" do
      @adapter.create_statement_with_returning(Cheese, Cheese.properties(@adapter.name).slice(:name)).should == <<-EOS.compress_lines
        INSERT INTO "cheeses" ("name") VALUES (?) RETURNING "id"
      EOS

      @adapter.create_statement_with_returning(Cheese, Cheese.properties(@adapter.name).slice(:color)).should == <<-EOS.compress_lines
        INSERT INTO "cheeses" ("color") VALUES (?) RETURNING "id"
      EOS
    end

  end

  describe "#update_statement" do

    it 'should generate a SQL statement for all fields' do
      @adapter.update_statement(Cheese, Cheese.properties(@adapter.name).slice(:name, :color)).should == <<-EOS.compress_lines
        UPDATE "cheeses" SET
        "name" = ?,
        "color" = ?
        WHERE "id" = ?
      EOS
    end

    it "should generate a SQL statement for only dirty fields" do
      @adapter.update_statement(Cheese, Cheese.properties(@adapter.name).slice(:name)).should == <<-EOS.compress_lines
        UPDATE "cheeses" SET "name" = ? WHERE "id" = ?
      EOS

      @adapter.update_statement(Cheese, Cheese.properties(@adapter.name).slice(:color)).should == <<-EOS.compress_lines
        UPDATE "cheeses" SET "color" = ? WHERE "id" = ?
      EOS
    end

    it "should generate a SQL statement that includes a Composite Key" do
      @adapter.update_statement(LittleBox, LittleBox.properties(@adapter.name).slice(:hillside)).should == <<-EOS.compress_lines
        UPDATE "little_boxes" SET "hillside" = ? WHERE "street" = ? AND "color" = ?
      EOS

      @adapter.update_statement(LittleBox, LittleBox.properties(@adapter.name).slice(:color, :hillside)).should == <<-EOS.compress_lines
        UPDATE "little_boxes" SET "color" = ?, "hillside" = ? WHERE "street" = ? AND "color" = ?
      EOS
    end

  end

  describe "#delete_statement" do

    it 'should generate a SQL statement for a serial Key' do
      @adapter.delete_statement(Cheese).should == <<-EOS.compress_lines
        DELETE FROM "cheeses" WHERE "id" = ?
      EOS
    end

    it "should generate a SQL statement for a Composite Key" do
      @adapter.delete_statement(LittleBox).should == <<-EOS.compress_lines
        DELETE FROM "little_boxes" WHERE "street" = ? AND "color" = ?
      EOS
    end

  end

  describe "#read_statement (without lazy attributes)" do
    it 'should generate a SQL statement for a serial Key' do
      @adapter.read_statement(Cheese, [1]).should == <<-EOS.compress_lines
        SELECT "id", "name", "color" FROM "cheeses" WHERE "id" = ?
      EOS
    end

    it "should generate a SQL statement that includes a Composite Key" do
      @adapter.read_statement(LittleBox, ['Shady Drive', 'Blue']).should == <<-EOS.compress_lines
        SELECT "street", "color", "hillside" FROM "little_boxes" WHERE "street" = ? AND "color" = ?
      EOS
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
        URI.parse("mysql://me:mypass@davidleal.com:5000/you_can_call_me_al?socket=nosock")
    end

    it 'should transform a minimal options hash into a URI' do
      options = {
        :adapter => 'mysql',
        :database => 'you_can_call_me_al'
      }

      adapter = DataMapper::Adapters::DataObjectsAdapter.new(:spec, options)
      adapter.uri.should == URI.parse("mysql:///you_can_call_me_al")
    end

    it 'should accept the uri when no overrides exist' do
      uri = URI.parse("protocol:///")
      DataMapper::Adapters::DataObjectsAdapter.new(:spec, uri).uri.should == uri
    end
  end
