module DataMapper
  module AutoMigrations
    def auto_migrate!
      if self::subclasses.empty?
        table = repository.table(self)
        table.activate_associations!
        
        table.create!(true)
      else
        schema = repository.schema
        columns = self::subclasses.inject(schema[self].columns) do |span, subclass|
          span + schema[subclass].columns
        end

        table_name = schema[self].name.to_s
        table = schema[table_name]
        columns.each do |column|
          table.add_column(column.name, column.type, column.options)
        end
        
        table.activate_associations!
        
        return table.create!(true)
      end
    end
    
    private
    def create_table(table)
      raise NotImplementedError.new
    end
    
    def modify_table(table, columns)
      raise NotImplementedError.new
    end
  end
end
