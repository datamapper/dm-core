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
        self.relationships(repository_name).each_pair { |name, relationship| relationship.child_key }
        repository(repository_name).adapter.destroy_model_storage(repository(repository_name), self)
        repository(repository_name).adapter.create_model_storage(repository(repository_name), self)
      end
    end
  end
  
  class AutoMigrator
    
    def self.models
      @@models ||= []
    end
    
    def self.auto_migrate(repository_name)
      # First ensure that association keys are forced to load.
      models.each do |model|
        model.relationships(repository_name).each_pair do |name, relationship|
          relationship.child_key
        end
      end
      
      models.each do |model|
        model.auto_migrate!(repository_name)
      end
    end
  end
end # module DataMapper