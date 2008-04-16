module DataMapper
  module DestructiveMigrations
    def self.included(model)
      DestructiveMigrator.models << model
    end
  end
  
  class DestructiveMigrator < Migrator
    def self.migrate(repository)
      models.each do |model|
        repository.adapter.destroy_store(repository, model)
        repository.adapter.create_store(repository, model)
      end
    end
  end
end