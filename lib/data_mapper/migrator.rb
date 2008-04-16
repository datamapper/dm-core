module DataMapper
  class Migrator
    def self.subclasses
      @@subclasses ||= []
    end
    
    def self.subclasses=(obj)
      @@subclasses = obj
    end
    
    def self.inherited(klass)
      subclasses << klass
      
      class << klass
        def models
          @models ||= []
        end
      end
    end
    
    def self.migrate(repository)
      subclasses.collect do |migrator|
        migrator.migrate(repository)
      end.flatten
    end
  end
end
    