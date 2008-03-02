module DataMapper
  module Adapters
    module Sql
      module Mappings
    
        # TODO: There are of course many more options to add here.
        # Ordinal, Length/Size, Nullability are just a few.
        class Column
          attr_reader :type, :name, :ordinal, :size, :default, :check
          attr_writer :lazy, :index, :unique
          attr_accessor :table, :options
          
          def initialize(adapter, table, name, type, ordinal, options = {})
            @adapter = adapter
            @table = table
            @name, self.type, @options = name.to_sym, type, options
            @ordinal = ordinal
            parse_options!
          end
          
          def parse_options!
            @key = @options[:key] == true || @options[:serial] == true
            @nullable = @options.has_key?(:nullable) ? @options[:nullable] : !@key
            @lazy = @options.has_key?(:lazy) ? @options[:lazy] : (@type == :text && !@key)
            @serial = @options[:serial] == true
            @default = @options[:default]
            
            @unique = if @options[:index] == :unique then @options.delete(:index); true else false end
            @index = @options[:index]
            @check = @options[:check] # only for postgresql
            
            @size = if @options.has_key?(:size)
              @options[:size]
            elsif @options.has_key?(:length)
              @options[:length]
            else
              case type
                when :integer then 11
                when :string, :class then 50
                else nil
              end
            end
            @size = @size.last if @size.is_a?(Range)
          end
          
          def defaulted?() instance_variables.include?("@default") end
          
          def type=(value)
            self.flush_sql_caches!
            @type = value
            (class << self; self end).class_eval <<-EOS
              def type_cast_value(value)
                @adapter.type_cast_#{@type}(value)
              end
            EOS
            @type
          end
          
          def name=(value)
            flush_sql_caches!
            @name = value
          end

          # Determines if the field should be lazy loaded.
          # You can set this explicitly, or accept the default,
          # which is false for all but text fields.
          def lazy?
            @lazy
          end
      
          def nullable?
            @nullable
          end
      
          def key?
            @key
          end
          
          def serial?
            @serial
          end
          
          def unique?
          	@unique
          end
          
          def index?
          	@index
          end

          def default=(value)
            self.flush_sql_caches!
            @default = value
          end
          
          def to_sym
            @name
          end
      
          def instance_variable_name
            @instance_variable_name || (@instance_variable_name = "@#{@name.to_s.gsub(/\?$/, '')}".freeze)
          end
      
          def to_s
            @name.to_s
          end
      
          def column_name
            @column_name || (@column_name = (@options.has_key?(:column) ? @options[:column].to_s : name.to_s.gsub(/\?$/, '')).freeze)
          end
      
          def to_sql(include_table_name = false)
            if include_table_name
              @to_sql_with_table_name || @to_sql_with_table_name = begin
                (@table.to_sql + '.' + @adapter.quote_column_name(column_name)).freeze
              end
            else
              @to_sql || (@to_sql = @adapter.quote_column_name(column_name).freeze)
            end
          end

          def size=(val)
            self.flush_sql_caches!
            @size = val
          end
      
          def inspect
            "#<%s:0x%x @name=%s, @type=%s, @options=%s>" % [self.class.name, (object_id * 2), to_sql, type.inspect, options.inspect]
          end
          
          def to_create_sql            
            "ALTER TABLE " <<  table.to_sql << " ADD " << to_long_form
          end
          
          def to_alter_sql
            "ALTER TABLE " <<  table.to_sql << " MODIFY COLUMN " << to_long_form
          end
          
          def to_drop_sql
            "ALTER TABLE " <<  table.to_sql << " DROP COLUMN " << to_sql
          end
                  
          def create!
            @table.columns << self
            flush_sql_caches!
            
            @adapter.connection do |db|
              command = db.create_command(to_create_sql)
              command.execute_non_query
            end
            true
          end
          
          def drop!
            @table.columns.delete(self)
            flush_sql_caches!
            
            @adapter.connection do |db|
              command = db.create_command(to_drop_sql)
              command.execute_non_query
            end
            true
          end
          
          def alter!
            flush_sql_caches!
            @adapter.connection do |db|
              command = db.create_command(to_alter_sql)
              command.execute_non_query
            end
            true
          end
          
          def rename!(new_name)
            old_name = name # Store the old_name
            
            new_column = @table.add_column(new_name, self.type, self.options.merge(:ordinal => self.ordinal))
            
            # Create the new column
            new_column.create!
            
            # Copy the data from one column to the other.
            @adapter.connection do |db|
              command = db.create_command <<-EOS.compress_lines
                UPDATE #{@table.to_sql} SET
                #{new_column.to_sql} = #{to_sql}
              EOS
              command.execute_non_query
            end
            
            self.drop!
            new_column
          end
          
          def to_long_form
            @to_long_form || begin
              @to_long_form = "#{to_sql} #{type_declaration}"
              
              unless nullable? || not_null_declaration.blank?
                @to_long_form << " #{not_null_declaration}"
              end
              
              # NOTE: We only do inline PRIMARY KEY declarations
              # if the column is also serial since we know
              # "there can be only one".
              if key? && serial? && !primary_key_declaration.blank?
                @to_long_form << " #{primary_key_declaration}"
              end
              
              if serial? && !serial_declaration.blank?
                @to_long_form << " #{serial_declaration}"
              end
              
              unless default.nil? || (value = default_declaration).blank?
                @to_long_form << " #{value}"
              end
              
              if unique? && !unique_declaration.blank?
                @to_long_form << " #{unique_declaration}"
              end
              
              @to_long_form
            end
          end
          
          def <=>(other)
            ordinal <=> other.ordinal
          end
          
          def hash
            @hash || @hash = to_sql(true).hash
          end
          
          def eql?(other)
            name == other.name
          end
          
          protected
          
          def primary_key_declaration
            "PRIMARY KEY"
          end
          
          def type_declaration
            sql = "#{@adapter.class::TYPES[type] || type}"
            sql << "(#{size})" unless size.nil?
            sql
          end
          
          def not_null_declaration
            "NOT NULL"
          end
          
          def serial_declaration
            "AUTO_INCREMENT"
          end
          
          def unique_declaration
          	"UNIQUE"
          end
          
          def default_declaration
            @adapter.connection { |db| db.create_command("DEFAULT ?").escape_sql([default]) }
          end
          
          def flush_sql_caches!
            @to_long_form = nil
            @to_sql = nil
            @to_sql_with_table_name = nil
            @column_name = nil
            @table.flush_sql_caches!(false)
          end
      
        end
    
      end
    end
  end
end
