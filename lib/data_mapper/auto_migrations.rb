module DataMapper
  class AutoMigrator
    def self.auto_migrate(repository_name)
      DataMapper::Resource.descendents.each do |model|
        model.auto_migrate!(repository_name)
      end
    end
    def self.auto_upgrade(repository_name)
      DataMapper::Resource.descendents.each do |model|
        model.auto_upgrade!(repository_name)
      end
    end
  end # class AutoMigrator

  module AutoMigrations
    def auto_migrate!(repository_name = default_repository_name)
      repository(repository_name) do |r|
        relationships(r.name).each_value { |relationship| relationship.child_key }
        r.adapter.destroy_model_storage(r, self)
        r.adapter.create_model_storage(r, self)
      end
    end
    def auto_upgrade!(repository_name = default_repository_name)
      repository(repository_name) do |r|
        relationships(r.name).each_value { |relationship| relationship.child_key }
        r.adapter.upgrade_model_storage(r, self)
      end
    end
  end # module AutoMigrations

  module Resource
    module ClassMethods
      include AutoMigrations
    end # module ClassMethods
  end # module Resource
end # module DataMapper
