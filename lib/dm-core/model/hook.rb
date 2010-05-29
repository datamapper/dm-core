module DataMapper
  module Model
    module Hook
      Model.append_inclusions self

      extend Chainable

      def self.included(model)
        model.send(:include, DataMapper::Hook)
        model.extend Methods
      end

      module Methods
        def inherited(model)
          copy_hooks(model)
          super
        end

        # @api public
        def before(target_method, method_sym = nil, &block)
          setup_hook(:before, target_method, method_sym, block) { super }
        end

        # @api public
        def after(target_method, method_sym = nil, &block)
          setup_hook(:after, target_method, method_sym, block) { super }
        end

        # @api private
        def hooks
          @hooks ||= {
            :save     => { :before => [], :after => [] },
            :create   => { :before => [], :after => [] },
            :update   => { :before => [], :after => [] },
            :destroy  => { :before => [], :after => [] },
          }
        end

      private

        def setup_hook(type, name, method, proc)
          types = hooks[name]
          if types && types[type]
            types[type] << if proc
              ProcCommand.new(proc)
            else
              MethodCommand.new(self, method)
            end
          else
            yield
          end
        end

        # deep copy hooks from the parent model
        def copy_hooks(model)
          hooks = Hash.new do |hooks, name|
            hooks[name] = Hash.new do |types, type|
              if self.hooks[name]
                types[type] = self.hooks[name][type].map do |command|
                  command.copy(model)
                end
              end
            end
          end

          model.instance_variable_set(:@hooks, hooks)
        end

      end

      class ProcCommand
        def initialize(proc)
          @proc = proc.to_proc
        end

        def call(resource)
          resource.instance_eval(&@proc)
        end

        def copy(model)
          self
        end
      end

      class MethodCommand
        def initialize(model, method)
          @model, @method = model, method.to_sym
        end

        def call(resource)
          resource.__send__(@method)
        end

        def copy(model)
          self.class.new(model, @method)
        end

      end

    end # module Hook
  end # module Model
end # module DataMapper
