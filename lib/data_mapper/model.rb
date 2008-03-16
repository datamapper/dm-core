require File.join(File.dirname(__FILE__), 'persistable')

module DataMapper
  class Model
    def self.inherited(klass)
      klass.send(:include, DataMapper::Persistable)
    end

    class IncompleteModelDefinitionError < StandardError
    end

  end
end
