module DataMapper
  module Model
    module Hook
      Model.append_inclusions self

      def self.included(model)
        model.send(:include, Extlib::Hook)
        model.extend Methods
        model.register_instance_hooks :create_hook, :update_hook, :destroy
      end

      module Methods
        # @api public
        def before(target_method, *args, &block)
          remap_target_method(target_method).each do |target_method|
            super(target_method, *args, &block)
          end
        end

        # @api public
        def after(target_method, *args, &block)
          remap_target_method(target_method).each do |target_method|
            super(target_method, *args, &block)
          end
        end

        private

        # @api private
        def remap_target_method(target_method)
          case target_method
            when :create then [ :create_hook               ]
            when :update then [ :update_hook               ]
            when :save   then [ :create_hook, :update_hook ]
            else              [ target_method              ]
          end
        end
      end

    end # module Hook
  end # module Model
end # module DataMapper
