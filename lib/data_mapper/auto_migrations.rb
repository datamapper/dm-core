module DataMapper
  module AutoMigrations
    
    def self.klasses
      @klasses ||= []
    end
    
    def self.included(klass)
      klass.extend(ClassMethods)
      #klass.send(:include, InstanceMethods)
      
      klasses << klass
    end
    
    def self.auto_migrate!
      klasses.each do |klass|
        klass.auto_migrate!
      end
    end
    
    module ClassMethods
      
      def auto_migrate!
        drop_object_store!
        create_object_store!
      end
      
    private
      
      def drop_object_store!
        raise NotImplementedError
      end
      
      def create_object_store!
        raise NotImplementedError
      end
    end
  end # module AutoMigrations
end # module DataMapper
