module DataMapper::Spec

  module AdapterHelpers

    def self.current_adapters
      @current_adapters ||= []
    end

    def supported_by(*adapters)
      adapters = get_adapters(*adapters)

      PRIMARY.only(*adapters).each do |adapter, connection_uri|
        # keep track of the current adapters
        AdapterHelpers.current_adapters << adapters

        message = "with #{adapter}" if adapters.length > 1

        with_adapter_spec_wrapper(message) do

          before(:each) do
            # store these in instance vars for the shared adapter specs
            @adapter = DataMapper.setup(:default, connection_uri)
            @repository = repository(:default)

            begin
              DataMapper.auto_migrate!
            rescue NotImplementedError
              # do nothing when not supported
            end
          end

          yield adapter
        end

        AdapterHelpers.current_adapters.pop
      end
    end

    def with_alternate_adapter
      adapters = AdapterHelpers.current_adapters.last

      ALTERNATE.only(*adapters).each do |adapter, connection_uri|
        message = "and #{adapter}" if adapters.length > 1
        with_adapter_spec_wrapper(message) do

          before(:each) do
            DataMapper.setup(:alternate, connection_uri)

            begin
              DataMapper.auto_migrate!(:alternate)
            rescue NotImplementedError
              # do nothing when not supported
            end
          end

          yield adapter
        end
      end
    end

    def get_adapters(*adapters)
      adapters.map! { |a| a.to_s }
      adapters = ADAPTERS if adapters.first == "all"
      ADAPTERS & adapters
    end

    def with_adapter_spec_wrapper(message)
      if message
        describe(message) do
          yield
        end
      else
        yield
      end
    end
  end
end
