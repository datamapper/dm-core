module DataMapper::Spec

  def self.included(receiver)
    receiver.extend AdapterHelpers
  end

  module AdapterHelpers

    def with_adapters(*adapters, &block)
      adapters = get_adapters(*adapters)

      adapters.each do |adapter, connection_uri|
        with_adapter_spec_wrapper(adapters, adapter) do
          before(:each) do
            @adapter = adapter
            DataMapper.setup(:default, connection_uri)
            DataMapper.auto_migrate!
          end

          block.call(adapter)
        end
      end
    end

    def get_adapters(*adapters)
      if !adapters.empty?
        ADAPTERS.only(*adapters)
      elsif ENV['ADAPTERS'] == 'all'
        ADAPTERS
      else
        ADAPTERS.only(*ENV['ADAPTERS'].strip.downcase.split(/\s+/))
      end
    end

    def with_adapter_spec_wrapper(adapters, current, &block)
      if adapters.keys.length > 1
        describe("with #{current}") do
          block.call
        end
      else
        yield
      end
    end

    def with_alternate
      # This would actually loop through all the alternate
      # adapters, but I'm too tired to finish it up
      before(:each) do
        if @adapter == 'mysql'
           DataMapper.setup(:alternate, ALTERNATE['postgres'])
        else
          DataMapper.setup(:alternate, ALTERNATE['mysql'])
        end
        repository(:alternate) { DataMapper.auto_migrate! }
      end

      yield
    end
  end
end
