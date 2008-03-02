require 'data_mapper/identity_map'

module DataMapper
  
  class Context
      
    class MaterializationError < StandardError
    end
    
    attr_reader :adapter
    
    def initialize(adapter)
      @adapter = adapter
    end
    
    def identity_map
      @identity_map || ( @identity_map = IdentityMap.new )
    end
    
    def first(klass, *args)
      id = nil
      options = nil
      table = self.table(klass)
      key = table.key
      
      if args.empty? # No id, no options
        options = { :limit => 1 }
      elsif args.size == 2 && args.last.kind_of?(Hash) # id AND options
        options = args.last.merge(key => args.first)
      elsif args.size == 1 # id OR options
        if args.first.kind_of?(Hash)
          options = args.first.merge(:limit => 1) # no id, add limit
        else
          options = { key => args.first } # no options, set id
        end
      else
        raise ArgumentError.new('Context#first takes a class, and optional type_or_id and/or options arguments')
      end
      
      # Account for undesired behaviour in MySQL that returns the
      # last inserted row when the WHERE clause contains a "#{primary_key} IS NULL".
      return nil if options.has_key?(key.name) && options[key.name] == nil
      
      @adapter.load(self, klass, options).first
    end
    
    def get(klass, keys)
      @adapter.get(self, klass, keys)
    end
    
    def all(klass, options = {})
      @adapter.load(self, klass, options)
    end
    
    def count(klass, *args)
      table(klass).count(*args)
    end
    
    def save(instance)
      @adapter.save(self, instance)
    end
    
    def destroy(instance)
      @adapter.delete(self, instance)
    end
    
    def delete_all(klass)
      @adapter.delete(self, klass)
    end
    
    def truncate(klass)
      table(klass).truncate!
    end
    
    def create_table(klass)
      table(klass).create!
    end
    
    def drop_table(klass)
      table(klass).drop!
    end
    
    def table_exists?(klass)
      table(klass).exists?
    end
    
    def column_exists_for_table?(klass, column_name)
      @adapter.column_exists_for_table?(klass, column_name)
    end
    
    def execute(*args)
      @adapter.execute(*args)
    end
    
    def query(*args)      
      @adapter.query(*args)
    end
    
    def schema
      @adapter.schema
    end
    
    def table(klass)
      @adapter.table(klass)
    end
    
    def logger
      @logger || @logger = @adapter.logger
    end

  end
end