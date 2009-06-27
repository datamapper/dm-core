require "benchmark"

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

          before :all do
            # store these in instance vars for the shared adapter specs
            @adapter    = DataMapper.setup(:default, connection_uri)
            @repository = DataMapper.repository(@adapter.name)

            # create all tables and constraints before each spec
            if @repository.respond_to?(:auto_migrate!)
              @repository.auto_migrate!
            end
          end

          after :all do
            # remove all tables and constraints after each spec
            if DataMapper.respond_to?(:auto_migrate_down!, true)
              DataMapper.send(:auto_migrate_down!, @repository.name)
            end
          end

          # TODO: add destroy_model_storage and migrations code
          # that removes the YAML file and remove this code
          after :all do
            if defined?(DataMapper::Adapters::YamlAdapter) && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)
              descendants = DataMapper::Model.descendants.to_a
              while model = descendants.shift
                descendants.concat(model.descendants.to_a - [ model ])

                model.default_scope.clear
                model.all(:repository => @repository).destroy!
              end
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

          before :all do
            @alternate_adapter    = DataMapper.setup(:alternate, connection_uri)
            @alternate_repository = DataMapper.repository(@alternate_adapter.name)

            # create all tables and constraints before each spec
            if @alternate_repository.respond_to?(:auto_migrate!)
              @alternate_repository.auto_migrate!
            end
          end

          after :all do
            # remove all tables and constraints after each spec
            if DataMapper.respond_to?(:auto_migrate_down!, true)
              DataMapper.send(:auto_migrate_down!, @alternate_repository.name)
            end
          end

          # TODO: add destroy_model_storage and migrations code
          # that removes the YAML file and remove this code
          after :all do
            if defined?(DataMapper::Adapters::YamlAdapter) && @alternate_adapter.kind_of?(DataMapper::Adapters::YamlAdapter)
              descendants = DataMapper::Model.descendants.to_a
              while model = descendants.shift
                descendants.concat(model.descendants.to_a - [ model ])

                model.default_scope.clear
                model.all(:repository => @alternate_repository).destroy!
              end
            end
          end

          self.instance_eval(&block)
        end
      end
    end

    def get_adapters(*adapters)
      adapters.map! { |adapter_name| adapter_name.to_s }
      adapters = ADAPTERS if adapters.include?('all')
      ADAPTERS & adapters
    end
  end
end
