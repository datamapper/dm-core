require File.expand_path(File.join(File.dirname(__FILE__), '..', "..", 'spec_helper'))

if HAS_POSTGRES
  describe DataMapper::Adapters::PostgresAdapter do
    before :all do
      @adapter = repository(:postgres).adapter
    end

    describe "auto migrating" do
      before :each do 
        class Sputnik
          include DataMapper::Resource

          property :id, Integer, :serial => true
          property :name, DM::Text
        end
        
        @connection = mock("connection")
        @command = mock("command")
        @result = mock("result")
      end
      it "#upgrade_model_storage should create sequences and then call super" do
        @adapter.should_receive(:create_connection).at_least(1).times.and_return(@connection)
        @connection.should_receive(:close).at_least(1).times
        @adapter.should_receive(:exists?).at_least(1).times.with("sputniks").and_return(true)
        @adapter.should_receive(:column_exists?).at_least(1).times.with("sputniks", "id").and_return(false)
        @adapter.should_receive(:column_exists?).at_least(1).times.with("sputniks", "name").and_return(false)
        @adapter.should_receive(:create_sequence_column).at_least(1).times.with(@connection, Sputnik, Sputnik.properties(:default)[:id])
        @command.should_receive(:execute_non_query).any_number_of_times.and_return(@result)
        @result.should_receive(:to_i).any_number_of_times.and_return(1)
        @connection.should_receive(:create_command).once.with("ALTER TABLE \"sputniks\" ADD COLUMN \"id\" INT4 NOT NULL DEFAULT nextval('sputniks_id_seq') NOT NULL").and_return(@command)
        @connection.should_receive(:create_command).once.with("ALTER TABLE \"sputniks\" ADD COLUMN \"name\" TEXT").and_return(@command)
        @adapter.upgrade_model_storage(nil, Sputnik).should == [Sputnik.properties(:default)[:id], Sputnik.properties(:default)[:name]]
      end
      it "#create_model_storage should create sequences and then call super" do
        @adapter.should_receive(:create_connection).at_least(1).times.and_return(@connection)
        @connection.should_receive(:close).at_least(1).times
        @adapter.should_receive(:create_sequence_column).at_least(1).times.with(@connection, Sputnik, Sputnik.properties(:default)[:id])
        @command.should_receive(:execute_non_query).any_number_of_times.with(any_args()).and_return(@result)
        @result.should_receive(:to_i).any_number_of_times.and_return(1)
        @connection.should_receive(:create_command).once.with("CREATE TABLE \"sputniks\" (\"id\" INT4 NOT NULL DEFAULT nextval('sputniks_id_seq') NOT NULL, \"name\" TEXT, PRIMARY KEY(\"id\"))").and_return(@command)
        @adapter.create_model_storage(nil, Sputnik)
      end
      it "#destroy_model_storage should drop sequences and then call super" do
        @adapter.should_receive(:create_connection).at_least(1).times.and_return(@connection)
        @connection.should_receive(:close).at_least(1).times
        @adapter.should_receive(:drop_sequence_column).at_least(1).times.with(@connection, Sputnik, Sputnik.properties(:default)[:id])
        @command.should_receive(:execute_non_query).any_number_of_times.with(any_args()).and_return(@result)
        @result.should_receive(:to_i).any_number_of_times.and_return(1)
        @connection.should_receive(:create_command).once.with("DROP TABLE IF EXISTS \"sputniks\"").and_return(@command)
        @adapter.destroy_model_storage(nil, Sputnik)
      end
    end
  end
end
