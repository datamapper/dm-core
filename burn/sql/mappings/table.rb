require File.dirname(__FILE__) + '/column'
require File.dirname(__FILE__) + '/conditions'
require File.dirname(__FILE__) + '/associations_set'

module DataMapper
  module Adapters
    module Sql
      module Mappings
    
        class Table
      
          attr_reader :klass, :name, :indexes, :composite_indexes
      
          def initialize(adapter, klass_or_name)
            raise "\"klass_or_name\" must not be nil!" if klass_or_name.nil?
            
            @klass = klass_or_name.kind_of?(String) ? nil : klass_or_name
            @klass_or_name = klass_or_name
            
            @adapter = adapter
            
            @temporary = false
            @columns = SortedSet.new
            @columns_hash = Hash.new { |h,k| h[k] = columns.find { |c| c.name == k } }
            
            @associations = AssociationsSet.new
            
            @multi_class = false
            @paranoid = false
            @paranoid_column = nil
            
            if @klass && @klass.respond_to?(:persistent?) && @klass.superclass.respond_to?(:persistent?)
              super_table = @adapter.table(@klass.superclass)
              
              super_table.columns.each do |column|
                self.add_column(column.name, column.type, column.options)
              end
              
              super_table.associations.each do |association|
                @associations << association
              end
            end
          end
          
          def schema
            @schema || @schema = @adapter.schema
          end
          
          def conditions(args)
            Conditions.new(self, @adapter, @associations.empty?, args)
          end
          
          def paranoid?
            @paranoid
          end
          
          def paranoid_column
            @paranoid_column
          end
          
          def multi_class?
            @multi_class
          end
          
          def type_column
            @type_column
          end
          
          def temporary?
            @temporary
          end
          
          def temporary=(value)
            @temporary = value
          end
          
          def associations
            @associations
          end
          
          def activate_associations!(force = false)
            @associations.each do |association|
              association.activate! force
            end
          end

          def reflect_columns
            @adapter.reflect_columns(self)
          end
          
          def columns
            key if @key.nil?
            class << self
              attr_reader :columns
            end
            
            self.columns
          end

          def mapped_column_exists?(column_name)
            @columns.each {|column| return true if column.name == column_name}
            false
          end
          
          def exists?
            @adapter.connection do |db|
              command = db.create_command(to_exists_sql)          
              command.execute_reader(name, schema.name) do |reader|
                reader.has_rows?
              end
            end
          end
          
          def drop!
            if exists?
              @adapter.connection do |db|
                result = db.create_command(to_drop_sql).execute_non_query
                repository.identity_map.clear!(name)
                schema.delete(self)
                true
              end
            else
              false
            end
          end
          
          def create!(force = false)
            if exists?
              if force
                drop!
                create!
              else
                false
              end
            else
              @adapter.connection do |db|
                db.create_command(to_create_sql).execute_non_query
                index_queries = to_create_index_sql + to_create_composite_index_sql
                index_queries.each { |q| db.create_command(q).execute_non_query }
                schema << self
                true
              end
            end
          end
          
          def delete_all!
            @adapter.connection do |db|
              db.create_command("DELETE FROM #{to_sql}").execute_non_query
            end
            repository.identity_map.clear!(name)
          end
          
          def truncate!
            @adapter.connection do |db|
              result = db.create_command(to_truncate_sql).execute_non_query
              repository.identity_map.clear!(name)
              result.to_i > 0
            end
          end
          
          def count(args={})
            sql = "SELECT COUNT(*) AS row_count FROM #{to_sql}"
            parameters = []
            
            paramsql, *parameters = conditions(args).to_params_sql
            sql << paramsql #gotta shift it in

            @adapter.connection do |db|              
              command = db.create_command(sql)
              command.execute_reader(*parameters) do |reader|
                if reader.has_rows?
                  reader.current_row.first.to_i
                else
                  0
                end
              end
            end
          end
          
          def insert(hash)
            @adapter.connection do |db|
              
              columns_to_insert = []
              values = []
              
              hash.each_pair do |k,v|
                column = self[k.to_sym]
                columns_to_insert << (column ? column.to_sql : k)
                values << v
              end
              
              command = db.create_command("INSERT INTO #{to_sql} (#{columns_to_insert.join(', ')}) VALUES (#{values.map { '?' }.join(', ')})")
              command.execute_non_query(*values)
            end
          end
          
          def key
            @key || begin
              @key = @columns.find { |column| column.key? }
              
              if @key.nil?
                unless @klass.nil?
                  @klass.send(:property, :id, :integer, :serial => true, :ordinal => -1)
                  @key = self[:id]
                else
                  @key = add_column(:id, :integer, :serial => true, :ordinal => -1)
                end
              end
              
              @key
            end
            
            class << self
              attr_accessor :key
            end
            Persistable::dependencies.resolve!
            
            self.key
          end
          
          def keys
            @keys || begin
              @keys = @columns.select { |column| column.key? }
            end
          end
          
          def indexes
          	@indexes || begin
          	  @indexes = @columns.select { |column| column.index? }
          	end
          end
          
          # Add a composite index to the table.
          # +index_columns+ should be an array including each column name.
          def add_composite_index(index_columns = [], unique = false)
            @composite_indexes ||= []
            @composite_indexes << [index_columns, unique] # add paired tuple with the index
          end
          
          def add_column(column_name, type, options = {})

            column_ordinal = if options.is_a?(Hash) && options.has_key?(:ordinal)
              options.delete(:ordinal)
            else
              @columns.size
            end
            
            column = @adapter.class::Mappings::Column.new(@adapter, self, column_name, type, column_ordinal, options)
            @columns << column
            
            if column_name == :type
              @multi_class = true
              @type_column = column
            end
            
            if column_name.to_s =~ /^deleted\_(at|on)$/
              @paranoid = true
              @paranoid_column = column
            end
            
            self.flush_sql_caches!
            @columns_hash.clear
            
            return column
          end
      
          def [](column_name)
            @columns_hash[column_name.to_sym]
          end
      
          def name
            @name || @name = begin
              if @custom_name
                @custom_name
              elsif @klass_or_name.kind_of?(String)
                @klass_or_name
              elsif @klass_or_name.kind_of?(Class)
                persistent_ancestor = @klass_or_name.superclass.respond_to?(:persistent?)
                if @klass_or_name.superclass.respond_to?(:persistent?)
                  @adapter.table(@klass_or_name.superclass).name
                else
                  Inflector.tableize(@klass_or_name.name)
                end
              else
                raise "+klass_or_name+ (#{@klass_or_name.inspect}) must be a Class or a string containing the name of a table"
              end
            end.freeze
          end
      
          def name=(value)
            flush_sql_caches!
            @custom_name = value
            self.name
          end
          
          def default_foreign_key
            @default_foreign_key ||= Inflector.foreign_key(@klass_or_name, key.name).freeze
          end
      
          def to_sql
            @to_sql ||= quote_table.freeze
          end
          
          def to_s
            name.to_s
          end
          
          def unquote_default(default)
            default
          end
          
          def get_database_columns
            columns = []            
            @adapter.connection do |db|
              command = db.create_command(to_columns_sql)
              command.execute_reader(name, schema.name) do |reader|
                columns = reader.map {
                  @adapter.class::Mappings::Column.new(@adapter, self, reader.item(1), 
                  @adapter.class::TYPES.index(reader.item(2)),reader.item(0).to_i,
                  :nullable => reader.item(3).to_i != 99, :default => unquote_default(reader.item(4)))
                }
              end
            end
            columns
          end
          alias_method :database_columns, :get_database_columns
          
          def to_create_sql            
            @to_create_sql || @to_create_sql = begin
              sql = "CREATE"
              sql << " TEMPORARY" if temporary?
              sql << " TABLE #{to_sql} (#{ columns.map { |c| c.to_long_form }.join(",\n") }"
              unless keys.blank? || (keys.size == 1 && keys.first.serial?)
                sql << ", PRIMARY KEY (#{keys.map { |c| c.to_sql }.join(', ') })"
              end
              sql << ")"
              
              sql.compress_lines
            end
          end
          
          # Returns an array with each separate CREATE INDEX statement
          def to_create_index_sql
            queries = []
            unless indexes.blank?
              indexes.each do |column|
                sql = "CREATE INDEX #{to_s.downcase}_#{column}_index ON "
                sql << "#{to_sql} (#{column.to_sql})"
                queries << sql.compress_lines
              end
            end
            queries
          end
          
          # Returns an array with each separate CREATE INDEX statement
          def to_create_composite_index_sql
            queries = []
            unless composite_indexes.blank?
              composite_indexes.each do |columns, unique|
                sql = "CREATE #{unique ? 'UNIQUE ' : ''}INDEX "
                sql << "#{to_s.downcase}_#{columns.join('_')}_index ON "
                sql << "#{to_sql} (#{columns.join(', ')})"
                queries << sql.compress_lines
              end
            end
            queries
          end
          
          def to_truncate_sql
            "TRUNCATE TABLE #{to_sql}"
          end
          
          def to_drop_sql
            @to_drop_sql || @to_drop_sql = "DROP TABLE #{to_sql}"
          end
          
          def to_exists_sql
            @to_exists_sql || @to_exists_sql = <<-EOS.compress_lines
              SELECT TABLE_NAME
              FROM INFORMATION_SCHEMA.TABLES
              WHERE TABLE_NAME = ?
                AND #{@adapter.database_column_name} = ?
            EOS
          end
          
          def to_column_exists_sql
            @to_column_exists_sql || @to_column_exists_sql = <<-EOS.compress_lines
              SELECT TABLE_NAME, COLUMN_NAME
              FROM INFORMATION_SCHEMA.COLUMNS
              WHERE TABLE_NAME = ?
              AND COLUMN_NAME = ?
                AND #{@adapter.database_column_name} = ?
            EOS
          end   
          
          def to_columns_sql
            @to_column_exists_sql || @to_column_exists_sql = <<-EOS.compress_lines
              SELECT ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE,
              (CASE IS_NULLABLE WHEN 'NO' THEN 99 ELSE 0 END),
              COLUMN_DEFAULT
              FROM INFORMATION_SCHEMA.COLUMNS
              WHERE TABLE_NAME = ?
              AND #{@adapter.database_column_name} = ?
            EOS
          end
          
          def quote_table
            @adapter.quote_table_name(name)
          end
      
          def inspect
            "#<%s:0x%x @klass=%s, @name=%s, @columns=%s>" % [
              self.class.name,
              (object_id * 2),
              klass.inspect,
              to_sql,
              @columns.inspect
            ]
          end
          
          def flush_sql_caches!(flush_columns = true)
            @to_column_exists_sql = nil
            @to_column_exists_sql = nil
            @to_exists_sql = nil
            @to_create_sql = nil
            @to_drop_sql = nil
            @to_sql = nil
            @name = nil
            @columns_hash.clear
            
            if flush_columns
              @columns.each do |column|
                column.send(:flush_sql_caches!)
              end
            end
            
            true
          end
          
          def activate!
            @activated = true
            activate_associations!
          end
          
          def activated?
            @activated
          end
          
        end
        
        class Schema
          def to_tables_sql
          end
        end
    
      end
    end
  end
end
