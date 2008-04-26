dir = Pathname(__FILE__).dirname.expand_path
require dir / 'migrator'

module DataMapper
  module AutoMigrations
    def self.included(model)
      model.extend ClassMethods
      DataMapper::AutoMigrator.models << model
    end
    
    module ClassMethods
      def auto_migrate!(repository_name = default_repository_name)
        repository(repository_name).adapter.destroy_model_storage(repository, self)
        repository(repository_name).adapter.create_model_storage(repository, self)
      end
    end
  end
  
  class AutoMigrator
    
    def self.models
      @@models ||= []
    end
    
    def self.auto_migrate(repository)
      models.each do |model|
        model.auto_migrate!
      end
    end
  end
end # module DataMapper