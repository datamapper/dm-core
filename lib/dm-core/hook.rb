module DataMapper
  module Hook
    def self.included(model)
      model.class_eval <<-EOS, __FILE__, __LINE__
        include Extlib::Hook
        register_instance_hooks :save, :create, :update, :destroy
      EOS
    end

    DataMapper::Resource.append_inclusions self
  end
end # module DataMapper
