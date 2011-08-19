module DataMapper
  module Spec
    module Adapters

      module Helpers

        def supported_by(*adapters, &block)
          adapters = adapters.map { |adapter| adapter.to_sym }
          adapter  = DataMapper::Spec.adapter_name.to_sym
          if adapters.include?(:all) || adapters.include?(adapter)
            describe_adapter(:default, &block)
          end
        end

        def with_alternate_adapter(&block)
          describe_adapter(:alternate, &block)
        end

        def describe_adapter(kind, &block)
          describe("with #{kind} adapter") do

            before :all do
              # store these in instance vars for the shared adapter specs
              @adapter    = DataMapper::Spec.adapter(kind)
              @repository = DataMapper.repository(@adapter.name)

              @repository.scope { DataMapper.finalize }

              # create all tables and constraints before each spec
              if @repository.respond_to?(:auto_migrate!)
                @repository.auto_migrate!
              end
            end

            after :all do
              # remove all tables and constraints after each spec
              if @repository.respond_to?(:auto_migrate_down!, true)
                @repository.send(:auto_migrate_down!, @repository.name)
              end
              # TODO consider proper automigrate functionality
              if @adapter.respond_to?(:reset)
                @adapter.reset
              end
            end

            instance_eval(&block)
          end
        end

      end

    end
  end
end
