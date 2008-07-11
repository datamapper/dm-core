# TODO: move to dm-more/dm-migrations

module DataMapper
  class AutoMigrator
    ##
    # Destructively automigrates the data-store to match the model
    # REPEAT: THIS IS DESTRUCTIVE
    #
    # @param Symbol repository_name the repository to be migrated
    # @calls DataMapper::Resource#auto_migrate!
    def self.auto_migrate(repository_name = nil)
      DataMapper::Resource.descendants.each do |model|
        model.auto_migrate!(repository_name)
      end
    end

    ##
    # Safely migrates the data-store to match the model
    # preserving data already in the data-store
    #
    # @param Symbol repository_name the repository to be migrated
    # @calls DataMapper::Resource#auto_upgrade!
    def self.auto_upgrade(repository_name = nil)
      DataMapper::Resource.descendants.each do |model|
        model.auto_upgrade!(repository_name)
      end
    end
  end # class AutoMigrator

  module AutoMigrations
    ##
    # Destructively automigrates the data-store to match the model
    # REPEAT: THIS IS DESTRUCTIVE
    #
    # @param Symbol repository_name the repository to be migrated
    def auto_migrate!(repository_name = nil)
      if self.superclass != Object
        self.superclass.auto_migrate!(repository_name)
      else
        repository(repository_name) do |r|
          r.adapter.destroy_model_storage(r, self)
          r.adapter.create_model_storage(r, self)
        end
      end
    end

    ##
    # Safely migrates the data-store to match the model
    # preserving data already in the data-store
    #
    # @param Symbol repository_name the repository to be migrated
    def auto_upgrade!(repository_name = nil)
      repository(repository_name) do |r|
        r.adapter.upgrade_model_storage(r, self)
      end
    end

    Model.send(:include, self)
  end # module AutoMigrations
end # module DataMapper
