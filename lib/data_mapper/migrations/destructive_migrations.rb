module DataMapper
  module DestructiveMigrations
    def self.included(model)
      DestructiveMigrator.models << model
    end
  end
  
  class DestructiveMigrator < Migrator
    def self.migrate(repository_name)
      models.each do |model|
        model.auto_migrate!
      end
    end
  end
end