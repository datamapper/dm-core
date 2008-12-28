module DataMapper
  module Hook
    def self.included(model)
      model.class_eval <<-EOS, __FILE__, __LINE__
        include Extlib::Hook

        register_instance_hooks :_create, :_update, :destroy

        def self.before(target_method, method_sym = nil, &block)
          remap_target_method(target_method).each do |target_method|
            super target_method, method_sym, &block
          end
        end

        def self.after(target_method, method_sym = nil, &block)
          remap_target_method(target_method).each do |target_method|
            super target_method, method_sym, &block
          end
        end

        class << self
          private

          def remap_target_method(target_method)
            case target_method
              when :create then [ :_create           ]
              when :update then [ :_update           ]
              when :save   then [ :_create, :_update ]
              else              [ target_method      ]
            end
          end
        end
      EOS
    end

    DataMapper::Resource.append_inclusions self
  end
end # module DataMapper
