require __DIR__ + 'abstract_adapter'

module DataMapper

  module Adapters

    # You must inherit from the DoAdapter, and implement the
    # required methods to adapt a database library for use with the DataMapper.
    #
    # NOTE: By inheriting from DataObjectsAdapter, you get a copy of all the
    # standard sub-modules (Quoting, Coersion and Queries) in your own Adapter.
    # You can extend and overwrite these copies without affecting the originals.
    class DataObjectsAdapter < AbstractAdapter

      FIND_OPTIONS = [
        :select, :offset, :limit, :class, :include, :shallow_include, :reload, :conditions, :order, :intercept_load
      ]

      def constants
        {
          :table_quoting_character  => %{},
          :column_quoting_character => %{},
          :true_aliases  => %w{1 T},
          :false_aliases => %w{0 F},
          :types => {
            :integer  => 'int'.freeze,
            :string   => 'varchar'.freeze,
            :text     => 'text'.freeze,
            :class    => 'varchar'.freeze,
            :decimal  => 'decimal'.freeze,
            :float    => 'float'.freeze,
            :datetime => 'datetime'.freeze,
            :date     => 'date'.freeze,
            :boolean  => 'boolean'.freeze,
            :object   => 'text'.freeze
          },
          :batch_insertable => true
        }
      end

      def transaction(&block)
        raise NotImplementedError.new
      end
      
      # all of our CRUD
      # Methods dealing with a single instance object
      def create(repository, instance)
        raise NotImplementedError.new
      end
      
      def read(repository, instance)
        raise NotImplementedError.new
      end
      
      def update(repository, instance)
        raise NotImplementedError.new
      end
      
      def delete(repository, instance)
        raise NotImplementedError.new
      end
      
      def save(repository, instance)
        if instance.new_record?
          create(repository, instance)
        else
          update(repository, instance)
        end
      end

      # Methods dealing with locating a single object, by keys
      def read_one(repository, klass, *keys)
        raise NotImplementedError.new
      end

      def delete_one(repository, klass, *keys)
        raise NotImplementedError.new
      end

      # Methods dealing with finding stuff by some query parameters
      def read_set(repository, klass, query = {})
        raise NotImplementedError.new
      end

      def delete_set(repository, klass, query = {})
        raise NotImplementedError.new
      end

      # Database-specific method
      def execute(*args)
        db = create_connection
        command = db.create_command(args.shift)
        return command.execute_non_query(*args)
      rescue => e
        DataMapper.logger.error { e } if DataMapper.logger
        raise e
      ensure
        db.close if db
      end

      def query(*args)
        db = create_connection

        command = db.create_command(args.shift)

        reader = command.execute_reader(*args)
        results = []

        if (fields = reader.fields).size > 1
          fields = fields.map { |field| Inflector.underscore(field).to_sym }
          struct = Struct.new(*fields)

          while(reader.next!) do
            results << struct.new(*reader.values)
          end
        else
          while(reader.next!) do
            results << reader.values[0]
          end
        end

        return results
      rescue => e
        DataMapper.logger.error { e } if DataMapper.logger
        raise e
      ensure
        reader.close if reader
        db.close if db
      end

      def delete(database_context, instance)
        table = self.table(instance)

        if instance.is_a?(Class)
          table.delete_all!
        else
          callback(instance, :before_destroy)

          table.associations.each do |association|
            instance.send(association.name).deactivate unless association.is_a?(::DataMapper::Associations::BelongsToAssociation)
          end

          if table.paranoid?
            instance.instance_variable_set(table.paranoid_column.instance_variable_name, Time::now)
            instance.save
          else
            if connection do |db|
                command = db.create_command("DELETE FROM #{table.to_sql} WHERE #{table.key.to_sql} = ?")
                command.execute_non_query(instance.key).to_i > 0
              end # connection do...end # if continued below:
              instance.instance_variable_set(:@new_record, true)
              instance.database_context = database_context
              instance.original_values.clear
              database_context.identity_map.delete(instance)
              callback(instance, :after_destroy)
            end
          end
        end
      end

      def save(database_context, instance, validate = true, cleared = Set.new)
        case instance
        when Class then
          table(instance).create!
          table(instance).activate_associations!
        when Mappings::Table then instance.create!
        when DataMapper::Persistable then
          event = instance.new_record? ? :create : :update

          return false if (validate && !instance.validate_recursively(event, Set.new)) || cleared.include?(instance)
          cleared << instance

          callback(instance, :before_save)

          return true unless instance.new_record? || instance.dirty?

          result = send(event, database_context, instance)

          instance.database_context = database_context
          instance.attributes.each_pair do |name, value|
            instance.original_values[name] = value
          end

          instance.loaded_associations.each do |association|
            association.save_without_validation(database_context, cleared) if association.dirty?
          end

          callback(instance, :after_save)
          result
        end
      rescue => error
        logger.error(error)
        raise error
      end

      def save_without_validation(database_context, instance, cleared = Set.new)
        save(database_context, instance, false, cleared)
      end

      def update(database_context, instance)
        callback(instance, :before_update)

        instance = update_magic_properties(database_context, instance)

        table = self.table(instance)
        attributes = instance.dirty_attributes
        parameters = []

        unless attributes.empty?
          sql = "UPDATE " << table.to_sql << " SET "

          sql << attributes.map do |key, value|
            parameters << value
            "#{table[key].to_sql} = ?"
          end.join(', ')

          sql << " WHERE #{table.key.to_sql} = ?"
          parameters << instance.key

          result = connection do |db|
            db.create_command(sql).execute_non_query(*parameters)
          end

          # BUG: do_mysql returns inaccurate affected row counts for UPDATE statements.
          if true || result.to_i > 0
            callback(instance, :after_update)
            return true
          else
            return false
          end
        else
          true
        end
      end

      def empty_insert_sql
        "DEFAULT VALUES"
      end

      def create(database_context, instance)
        callback(instance, :before_create)

        instance = update_magic_properties(database_context, instance)

        table = self.table(instance)
        attributes = instance.dirty_attributes

        if table.multi_class?
          instance.instance_variable_set(
            table[:type].instance_variable_name,
            attributes[:type] = instance.class.name
          )
        end

        keys = []
        values = []
        attributes.each_pair do |key, value|
          raise ArgumentError.new("#{value.inspect} is not a valid value for #{key.inspect}") if value.is_a?(Array)

          keys << table[key].to_sql
          values << value
        end

        sql = if keys.size > 0
          "INSERT INTO #{table.to_sql} (#{keys.join(', ')}) VALUES ?"
        else
          "INSERT INTO #{table.to_sql} #{self.empty_insert_sql}"
        end

        result = connection do |db|
          db.create_command(sql).execute_non_query(values)
        end

        if result.to_i > 0
          instance.instance_variable_set(:@new_record, false)
          instance.key = result.last_insert_row if table.key.serial? && !attributes.include?(table.key.name)
          database_context.identity_map.set(instance)
          callback(instance, :after_create)
          return true
        else
          return false
        end
      end

      MAGIC_PROPERTIES = {
        :updated_at => lambda { self.updated_at = Time::now },
        :updated_on => lambda { self.updated_on = Date::today },
        :created_at => lambda { self.created_at ||= Time::now },
        :created_on => lambda { self.created_on ||= Date::today }
      }

      def update_magic_properties(database_context, instance)
        instance.class.properties.find_all { |property| MAGIC_PROPERTIES.has_key?(property.name) }.each do |property|
          instance.instance_eval(&MAGIC_PROPERTIES[property.name])
        end
        instance
      end

      def load(database_context, klass, options)
        self.class::Commands::LoadCommand.new(self, database_context, klass, options).call
      end

      def table_name(resource_name)
        resource_name.to_s.ensure_wrapped_with('"')
      end
      
      def column_name(field_name)
        field_name.to_s.ensure_wrapped_with('"')
      end
      
      def get(context, target, key_values)
        instance = nil
        
        table_name = table_name(target.resource_name(repository.name))
        column_names = target.properties(repository.name).map do |property|
          column_name(property.field)
        end
        key_columns = target.key.map { |property| column_name(property.field) }

        sql = "SELECT #{column_names.join(', ')} FROM #{table_name} WHERE #{key_columns.map { |key| "#{key} = ?" }.join(' AND ')}"
        
        connection = create_connection
        reader = nil
        
        begin
          reader = connection.create_command(sql).execute_reader(*key_values)

          instance_type = target

          # if table.multi_class? && table.type_column
          #   value = reader.item(column_indexes[table.type_column])
          #   instance_type = table.type_column.type_cast_value(value) unless value.blank?
          # end

          if instance.nil?
            instance = instance_type.allocate()
            # instance.instance_variable_set(:@__key, instance_id)
            instance.instance_variable_set(:@new_record, false)
            database_context.identity_map.set(instance)
          elsif instance.new_record?
            # instance.instance_variable_set(:@__key, instance_id)
            instance.instance_variable_set(:@new_record, false)
            database_context.identity_map.set(instance)
          end

          instance.database_context = database_context

          instance_type.callbacks.execute(:before_materialize, instance)

          originals = instance.original_values

          column_indexes.each_pair do |column, i|
            value = column.type_cast_value(reader.item(i))
            instance.instance_variable_set(column.instance_variable_name, value)

            case value
              when String, Date, Time then originals[column.name] = value.dup
              else originals[column.name] = value
            end
          end

          instance.loaded_set = [instance]

          instance_type.callbacks.execute(:after_materialize, instance)
        ensure
          reader.close if reader
          connection.close
        end

        return instance
      end

      def callback(instance, callback_name)
        instance.class.callbacks.execute(callback_name, instance)
      end

      module SQL
        def self.create_statement(adapter, instance)
          dirty_attribute_names = instance.dirty_attributes.keys
          properties = instance.class.properties(adapter.name).select { |property| dirty_attribute_names.include?(property.name) }
          <<-EOS.compress_lines
            INSERT INTO #{adapter.quote_table_name(instance.class.resource_name(adapter.name))}
            (#{properties.map { |property| adapter.quote_column_name(property.field) }.join(', ')})
            VALUES
            (#{(['?'] * properties.size).join(', ')})
          EOS
        end

        def self.create_statement_with_returning(adapter, instance)
          dirty_attribute_names = instance.dirty_attributes.keys
          properties = instance.class.properties(adapter.name).select { |property| dirty_attribute_names.include?(property.name) }
          <<-EOS.compress_lines
            INSERT INTO #{adapter.quote_table_name(instance.class.resource_name(adapter.name))}
            (#{properties.map { |property| adapter.quote_column_name(property.field) }.join(', ')})
            VALUES
            (#{(['?'] * properties.size).join(', ')})
            RETURNING #{adapter.quote_column_name(instance.class.key(adapter.name).first.field)}
          EOS
        end
        
        def self.update_statement(adapter, instance)
          dirty_attribute_names = instance.dirty_attributes.keys
          properties = instance.class.properties(adapter.name).select { |property| dirty_attribute_names.include?(property.name) }
          <<-EOS.compress_lines
            UPDATE #{adapter.quote_table_name(instance.class.resource_name(adapter.name))} 
            SET #{properties.map {|attribute| "#{adapter.quote_column_name(attribute.field)} = ?" }.join(', ')}
            WHERE #{instance.class.key(adapter.name).map { |key| "#{adapter.quote_column_name(key.field)} = ?" }.join(' AND ')}
          EOS
        end
        
        def self.delete_statement(adapter, instance)
          <<-EOS.compress_lines
            DELETE FROM #{adapter.quote_table_name(instance.class.resource_name(adapter.name))} 
            WHERE #{instance.class.key(adapter.name).map { |key| "#{adapter.quote_column_name(key.field)} = ?" }.join(' AND ')}
          EOS
        end
        
        def self.read_statement(adapter, resource, key)
          properties = resource.properties(adapter.name).select { |property| !property.lazy? }
          <<-EOS.compress_lines
            SELECT #{properties.map { |property| adapter.quote_column_name(property.field) }.join(', ')} 
            FROM #{adapter.quote_table_name(resource.resource_name(adapter.name))} 
            WHERE #{resource.key(adapter.name).map { |key| "#{adapter.quote_column_name(key.field)} = ?" }.join(' AND ')}
          EOS
        end
        
      end #module SQL
      
      # Adapters requiring a RETURNING syntax for create statements
      # should overwrite this to return true.
      def syntax_returning?
        false
      end

      def quote_table_name(table_name)
        table_name.ensure_wrapped_with('"')
      end

      def quote_column_name(column_name)
        column_name.ensure_wrapped_with('"')
      end
      
      def self.inherited(target)
        sql = target.const_set('SQL', Module.new)
        sql.send(:include, SQL)
      end
      
    end # class DoAdapter

  end # module Adapters
end # module DataMapper
