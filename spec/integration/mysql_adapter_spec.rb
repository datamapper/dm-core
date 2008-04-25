require File.join(File.dirname(__FILE__), '..', 'spec_helper')

begin
  gem 'do_mysql', '=0.9.0'
  require 'do_mysql'

  DataMapper.setup(:mysql, "mysql://localhost/dm_core_test")

  describe DataMapper::Adapters::DataObjectsAdapter do
    before :all do
      @adapter = repository(:mysql).adapter
    end

    describe "handling transactions" do
      before :all do
        @adapter.execute('DROP TABLE IF EXISTS sputniks')
        @adapter.execute('CREATE TABLE sputniks (id serial, name text) ENGINE = innodb')
      end

      before :each do
        @transaction = DataMapper::Adapters::Transaction.new(@adapter)
      end

      it "should rollback changes when #rollback_transaction is called" do
        @transaction.commit do |trans|
          @adapter.execute("INSERT INTO sputniks (name) VALUES ('my pretty sputnik')")
          trans.rollback
        end
        @adapter.query("SELECT * FROM sputniks WHERE name = 'my pretty sputnik'").empty?.should == true
      end
      it "should commit changes when #commit_transaction is called" do
        @transaction.commit do
          @adapter.execute("INSERT INTO sputniks (name) VALUES ('my pretty sputnik')")
        end
        @adapter.query("SELECT * FROM sputniks WHERE name = 'my pretty sputnik'").size.should == 1
      end
    end

  end
rescue LoadError => e
  describe 'do_mysql' do
    it 'should be required' do
      fail "MySQL integration specs not run! Could not load do_mysql: #{e}"
    end
  end
end
