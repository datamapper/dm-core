# TODO: figure out a different way to mix in the specific hooks below,
# since Resource#save! and Resource#update! also use Resource#_create
# and Resource#_update.  This means any before :create or before :update
# hooks will also be applied to the ! versions of the Resource methods

module DataMapper
  module Model
    module Hook
      Model.append_inclusions self

      def self.included(model)
        model.send(:include, Extlib::Hook)
        model.extend Methods
        model.register_instance_hooks :_create, :_update, :destroy
      end

      module Methods
        # TODO: document
        # @api public
        def before(target_method, *args, &block)
          remap_target_method(target_method).each do |target_method|
            super(target_method, *args, &block)
          end
        end

        # TODO: document
        # @api public
        def after(target_method, *args, &block)
          remap_target_method(target_method).each do |target_method|
            super(target_method, *args, &block)
          end
        end

        private

        # TODO: document
        # @api private
        def remap_target_method(target_method)
          case target_method
            when :create then [ :_create           ]
            when :update then [ :_update           ]
            when :save   then [ :_create, :_update ]
            else              [ target_method      ]
          end
        end
      end

    end # module Hook
  end # module Model
end # module DataMapper
