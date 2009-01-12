module DataMapper::Spec
  module AdapterHelpers
    def self.current_adapters
      @current_adapters ||= []
    end

    def supported_by(*adapters, &block)
      adapters = get_adapters(*adapters)

      PRIMARY.only(*adapters).each do |adapter, connection_uri|
        # keep track of the current adapters
        AdapterHelpers.current_adapters << adapters

        describe("with #{adapter}") do

          before do
            # store these in instance vars for the shared adapter specs
            @adapter = DataMapper.setup(:default, connection_uri)
            @repository = repository(@adapter.name)

            # create all tables and constraints before each spec
            begin
              DataMapper.auto_migrate!(@adapter.name)
            rescue NotImplementedError, NoMethodError
              # do nothing when not supported
            end
          end

          after do
            # remove all tables and constraints after each spec
            begin
              DataMapper::AutoMigrator.auto_migrate_down(@adapter.name)
            rescue NotImplementedError, NoMethodError
              # do nothing when not supported
            end
          end

          self.instance_eval(&block)
        end

        AdapterHelpers.current_adapters.pop
      end
    end

    def with_alternate_adapter(&block)
      adapters = AdapterHelpers.current_adapters.last

      ALTERNATE.only(*adapters).each do |adapter, connection_uri|
        describe("and #{adapter}") do

          before do
            @alternate_adapter = DataMapper.setup(:alternate, connection_uri)

            # create all tables and constraints before each spec
            begin
              DataMapper.auto_migrate!(@alternate_adapter.name)
            rescue NotImplementedError, NoMethodError
              # do nothing when not supported
            end
          end

          after do
            # remove all tables and constraints after each spec
            begin
              DataMapper::AutoMigrator.auto_migrate_down(@alternate_adapter.name)
            rescue NotImplementedError, NoMethodError
              # do nothing when not supported
            end
          end

          self.instance_eval(&block)
        end
      end
    end

    def get_adapters(*adapters)
      adapters.map! { |a| a.to_s }
      adapters = ADAPTERS if adapters.include?('all')
      ADAPTERS & adapters
    end
  end
end
