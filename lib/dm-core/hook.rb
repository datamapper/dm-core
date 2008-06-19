module DataMapper
  module Hook
    def self.included(model)
      model.class_eval %{
        include Extlib::Hook
        register_instance_hooks :save, :create, :update, :destroy
      }
    end
  end
  DataMapper::Resource.append_inclusions Hook
end # module DataMapper
