module DataMapper::Spec

  def self.included(receiver)
    receiver.extend AdapterHelpers
  end

  module AdapterHelpers

    def with_adapters(*adapters)
      adapters = get_adapters(*adapters)

      adapters.each do |adapter, connection_uri|
        with_adapter_spec_wrapper(adapters, adapter) do
          before(:each) do
            @adapter = adapter
            DataMapper.setup(:default, connection_uri)

            begin
              DataMapper.auto_migrate!
            rescue NotImplementedError
              # do nothing when not supported
            end
          end

          yield adapter
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

    def with_adapter_spec_wrapper(adapters, current)
      if adapters.keys.length > 1
        describe("with #{current}") do
          yield
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
    rescue Gem::LoadError
      # do nothing for now
    end
  end
end
