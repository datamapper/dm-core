module DataMapper
  class Migrator
    def self.subclasses
      @@subclasses ||= []
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
      subklasses = subclasses.dup
      until subclasses.empty?
        migrator = subclasses.shift
        #DataMapper.logger.debug!("Loading: #{migrator}") if ENV['DEBUG']
        Object.const_get(migrator).migrate(repository)
      end
      self.subclasses = subklasses
    end
  end
end
    