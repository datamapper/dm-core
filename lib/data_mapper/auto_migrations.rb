require __DIR__ + 'migrator'

module DataMapper
  module AutoMigrations
    def self.included(model)
      model.extend ClassMethods
      DataMapper::AutoMigrator.models << model
    end
    
    module ClassMethods
      def auto_migrate!(repository_name = default_repository_name)
        repository(repository_name).adapter.destroy_store(repository, self)
        repository(repository_name).adapter.create_store(repository, self)
      end
    end
  end
  
  class AutoMigrator
    
    def self.models
      @@models ||= []
    end
    
    def self.auto_migrate(repository)
      models.each do |model|
        repository.adapter.destroy_store(repository, model)
        repository.adapter.create_store(repository, model)
      end
    end
  end
end # module DataMapper