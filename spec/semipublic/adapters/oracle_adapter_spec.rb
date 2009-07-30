require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

dir = DataMapper.root / 'lib' / 'dm-core' / 'spec'

require dir / 'adapter_shared_spec'
require dir / 'data_objects_adapter_shared_spec'

module SQLLogHelper
  class SQLLogger
    attr_accessor :buffer
    def initialize
      @buffer = ""
    end

    def level; 0; end

    def debug(string)
      @buffer << string << "\n"
      # puts "#{string.gsub(/\n/m,"<br/>\n")}<br/>"
    end
  end

  def start_sql_log!
    return if @sql_log_on
    @sql_log_on = true
    @old_logger = DataObjects::Oracle.logger
    DataObjects::Oracle.logger = SQLLogger.new
  end

  def stop_sql_log!
    return unless @sql_log_on
    @sql_log_on = nil
    DataObjects::Oracle.logger = @old_logger
  end

  def clear_sql_log!
    return unless @sql_log_on
    DataObjects::Oracle.logger.buffer = ""
  end

  def sql_log_buffer
    DataObjects::Oracle.logger.buffer
  end
end

describe 'Adapter' do
  supported_by :oracle do
    describe DataMapper::Adapters::OracleAdapter do

      it_should_behave_like 'An Adapter'
      it_should_behave_like 'A DataObjects Adapter'

      describe "sequences" do
        include SQLLogHelper

        before(:all) do
          @auto_migrate_with = DataMapper::Adapters::OracleAdapter.auto_migrate_with
          DataMapper::Adapters::OracleAdapter.auto_migrate_with :drop_and_create
          start_sql_log!
        end

        after(:all) do
          stop_sql_log!
          DataMapper::Adapters::OracleAdapter.auto_migrate_with @auto_migrate_with
        end

        describe "create default sequence and trigger" do
          before(:all) do
            class ::Employee
              include DataMapper::Resource
              property :employee_id,  Serial
            end
            Employee.auto_migrate!
          end

          after(:all) do
            Employee.auto_migrate_down!
          end

          it "should not have sequence name in options" do
            Employee.properties[:employee_id].options[:sequence].should be_nil
          end

          it "should create default sequence" do
            sql_log_buffer.should =~ /CREATE SEQUENCE "EMPLOYEES_SEQ"/
          end

          it "should create trigger" do
            sql_log_buffer.should =~ /CREATE OR REPLACE TRIGGER "EMPLOYEES_PKT"/
          end

        end

        describe "create custom sequence" do

          before(:all) do
            class ::Employee
              include DataMapper::Resource
              property :employee_id,  Serial, :sequence => "emp_seq"
            end
            Employee.auto_migrate!
          end

          after(:all) do
            Employee.auto_migrate_down!
          end

          it "should have custom sequence name" do
            Employee.properties[:employee_id].options[:sequence].should == "emp_seq"
          end

          it "should create custom sequence" do
            sql_log_buffer.should =~ /CREATE SEQUENCE "EMP_SEQ"/
          end

          it "should not create trigger" do
            sql_log_buffer.should_not =~ /TRIGGER/
          end

        end

        describe "create custom sequence in non-default repository" do

          before(:all) do
            stop_sql_log!
            DataMapper.setup :oracle, DataMapper::Repository.adapters[:default].options
            start_sql_log!
            class ::Employee
              include DataMapper::Resource
              property :id,  Serial
              repository(:oracle) do
                property :id,  Serial, :field => "employee_id", :sequence => "emp_seq"
              end
            end
            repository(:oracle) do
              Employee.auto_migrate!
            end
          end

          after(:all) do
            repository(:oracle) do
              Employee.auto_migrate_down!
            end
          end

          it "should have custom sequence name" do
            Employee.properties(:oracle)[:id].options[:sequence].should == "emp_seq"
          end

          it "should create custom sequence" do
            sql_log_buffer.should =~ /CREATE SEQUENCE "EMP_SEQ"/
          end

          it "should not create trigger" do
            sql_log_buffer.should_not =~ /TRIGGER/
          end

        end

        describe "prefetch key value from custom sequence" do

          before(:all) do
            class ::Employee
              include DataMapper::Resource
              property :employee_id,  Serial, :sequence => "emp_seq"
              property :first_name,   String
            end
            Employee.auto_migrate!
          end

          after(:all) do
            Employee.auto_migrate_down!
          end

          it "should prefetch sequence value when inserting new record" do
            e = Employee.create
            e.employee_id.should == 1
            e = Employee.create(:first_name => "Raimonds")
            e.employee_id.should == 2
          end

          it "should insert explicitly specified primary key value" do
            e = Employee.create(:employee_id => 100,:first_name => "Raimonds")
            e.employee_id.should == 100
          end

        end


      end

    end
  end
end
