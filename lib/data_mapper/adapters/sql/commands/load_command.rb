module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class LoadCommand
          
          class Loader

            def initialize(load_command, klass)
              @load_command, @klass = load_command, klass
              @columns = {}
              @key = nil
              @key_index = nil
              @type_override_present = false
              @type_override_index = nil
              @type_override = nil
              @database_context = load_command.database_context
              @reload = load_command.reload?
              @set = []
            end

            def add_column(column, index)
              if column.key?
                @key = column 
                @key_index = index
              end

              if column.type == :class
                @type_override_present = true
                @type_override_index = index
                @type_override = column
              end

              @columns[index] = column

              self
            end

            def materialize(values)
              instance_id = @key.type_cast_value(values[@key_index])
              instance = create_instance(instance_id,
                if @type_override_present
                  @type_override.type_cast_value(values[@type_override_index]) || @klass
                else
                  @klass
                end
              )
              
              @klass.callbacks.execute(:before_materialize, instance)

              type_casted_values = {}
              
              @columns.each_pair do |index, column|
                # This may be a little confusing, but we're
                # setting both the original_value, and the
                # instance-variable through method chaining to avoid
                # lots of extra short-lived local variables.
                begin
                  type_casted_values[column.name] = instance.instance_variable_set(
                    column.instance_variable_name,
                    column.type_cast_value(values[index])
                  )
                rescue => e
                  raise MaterializationError.new("Failed to materialize column #{column.name.inspect} with value #{values[index].inspect}\n#{e.display}")
                end
              end
              
              instance.original_values = type_casted_values
              instance.instance_variable_set(:@loaded_set, @set)
              @set << instance

              @klass.callbacks.execute(:after_materialize, instance)

              return instance
              
            rescue => e
              if e.is_a?(MaterializationError)
                raise e
              else
                raise MaterializationError.new("Failed to materialize row: #{values.inspect}\n#{e.display}")
              end
            end

            def loaded_set
              @set
            end

            private
                
              def create_instance(instance_id, instance_type)
                instance = @database_context.identity_map.get(@klass, instance_id)

                if instance.nil? || @reload
                  instance = instance_type.allocate() if instance.nil?
                  instance.instance_variable_set(:@__key, instance_id)
                  instance.instance_variable_set(:@new_record, false)
                  @database_context.identity_map.set(instance)
                elsif instance.new_record?
                  instance.instance_variable_set(:@__key, instance_id)
                  instance.instance_variable_set(:@new_record, false)
                end

                instance.database_context = @database_context

                return instance
              end

          end
          
          class ConditionsError < StandardError

            attr_reader :inner_error

            def initialize(clause, value, inner_error)
              @clause, @value, @inner_error = clause, value, inner_error
            end

            def message
              "Conditions (:clause => #{@clause.inspect}, :value => #{@value.inspect}) failed: #{@inner_error}"
            end

            def backtrace
              @inner_error.backtrace
            end              

          end
          
          attr_reader :conditions, :database_context, :options
          
          def initialize(adapter, database_context, primary_class, options = {})
            @adapter, @database_context, @primary_class = adapter, database_context, primary_class
            
            # BEGIN: Partion out the options hash into general options,
            # and conditions.
            standard_find_options = @adapter.class::FIND_OPTIONS
            conditions_hash = {}
            @options = {}
            
            options.each do |key,value|
              if standard_find_options.include?(key) && key != :conditions
                @options[key] = value
              else
                conditions_hash[key] = value
              end
            end
            # END
            
            @order = @options[:order]
            @limit = @options[:limit]
            @offset = @options[:offset]
            @reload = @options[:reload]
            @instance_id = conditions_hash[:id]
            @conditions = parse_conditions(conditions_hash)
            @loaders = Hash.new { |h,k| h[k] = Loader.new(self, k) }
          end
          
          # Display an overview of load options at a glance.          
          def inspect
            <<-EOS.compress_lines % (object_id * 2)
              #<#{self.class.name}:0x%x
                @database=#{@adapter.name}
                @reload=#{@reload.inspect}
                @order=#{@order.inspect}
                @limit=#{@limit.inspect}
                @offset=#{@offset.inspect}
                @options=#{@options.inspect}>
            EOS
          end
                              
          # Access the Conditions instance
          def conditions
            @conditions
          end
          
          # If +true+ then force the command to reload any objects
          # already existing in the IdentityMap when executing.
          def reload?
            @reload
          end
          
          # Determine if there is a limitation on the number of
          # instances returned in the results. If +nil+, no limit
          # is set. Can be used in conjunction with #offset for
          # paging through a set of results.
          def limit
            @limit
          end
          
          # Used in conjunction with #limit to page through a set
          # of results.
          def offset
            @offset
          end
          
          def call
            
            # Check to see if the query is for a specific id and return if found
            #
            # NOTE: If the :id option is an Array:
            # We could search for loaded instance ids and reject from
            # the Array for already loaded instances, but working under the
            # assumption that we'll probably have to issue a query to find
            # at-least some of the instances we're looking for, it's faster to
            # just skip that and go straight for the query.
            unless reload? || @instance_id.blank? || @instance_id.is_a?(Array)
              # If the id is for only a single record, attempt to find it.
              if instance = @database_context.identity_map.get(@primary_class, @instance_id)
                return [instance]
              end
            end
            
            results = []
            
            # Execute the statement and load the objects.
            @adapter.connection do |db|
              sql, *parameters = to_parameterized_sql
              command = db.create_command(sql)
              command.execute_reader(*parameters) do |reader|
                if @options.has_key?(:intercept_load)
                  load(reader, &@options[:intercept_load])
                else
                  load(reader)
                end
              end
            end
            
            results += @loaders[@primary_class].loaded_set
            
            return results
          end
          
          def load(reader)          
            # The following blocks are identical aside from the yield.
            # It's written this way to avoid a conditional within each
            # iterator, and to take advantage of the performance of
            # yield vs. Proc#call.
            if block_given?
              reader.each do
                @loaders.each_pair do |klass,loader|
                  row = reader.current_row
                  yield(loader.materialize(row), @columns, row)
                end
              end
            else
              reader.each do
                @loaders.each_pair do |klass,loader|
                  loader.materialize(reader.current_row)
                end
              end
            end
          end
          
          # Are any conditions present?
          def conditions_empty?
            @conditions.empty?
          end
          
          # Generate a select statement based on the initialization
          # arguments.
          def to_parameterized_sql
            parameters = []
            
            sql = 'SELECT ' << columns_for_select.join(', ')
            sql << ' FROM ' << from_table_name            
            
            included_associations.each do |association|
              sql << ' ' << association.to_sql
            end
            
            shallow_included_associations.each do |association|
              sql << ' ' << association.to_shallow_sql
            end
            
            unless conditions_empty?
              sql << ' WHERE ('
              
              last_index = @conditions.size
              current_index = 0
              
              @conditions.each do |condition|
                case condition
                when String then sql << condition
                when Array then
                    sql << condition.shift
                    parameters += condition
                else
                  raise "Unable to parse condition: #{condition.inspect}" if condition
                end
                
                if (current_index += 1) == last_index
                  sql << ')'
                else
                  sql << ') AND ('
                end
              end
            end # unless conditions_empty?
            
            unless @order.nil?
              sql << ' ORDER BY ' << @order.to_s
            end
        
            unless @limit.nil?
              sql << ' LIMIT ' << @limit.to_s
            end
            
            unless @offset.nil?
              sql << ' OFFSET ' << @offset.to_s
            end
            
            parameters.unshift(sql)
          end
          
          # If more than one table is involved in the query, the column definitions should
          # be qualified by the table name. ie: people.name
          # This method determines wether that needs to happen or not.
          # Note: After the first call, the calculations are avoided by overwriting this
          # method with a simple getter.
          def qualify_columns?
            @qualify_columns = !(included_associations.empty? && shallow_included_associations.empty?)
            def self.qualify_columns?
              @qualify_columns
            end
            @qualify_columns
          end
          
          # expression_to_sql takes a set of arguments, and turns them into a an
          # Array of generated SQL, followed by optional Values to interpolate as SQL-Parameters.
          #
          # Parameters:
          # +clause+ The name of the column as a Symbol, a raw-SQL String, a Mappings::Column
          # instance, or a Symbol::Operator.
          # +value+ The Value for the condition.
          # +collector+ An Array representing all conditions that is appended to by expression_to_sql
          #
          # Returns: Undefined Output. The work performed is added to the +collector+ argument.
          # Example:
          #   conditions = []
          #   expression_to_sql(:name, 'Bob', conditions)
          #   => +undefined return value+
          #   conditions.inspect
          #   => ["name = ?", 'Bob']
          def expression_to_sql(clause, value, collector)
            qualify_columns = qualify_columns?

            case clause
            when Symbol::Operator then
              operator = case clause.type
              when :gt then '>'
              when :gte then '>='
              when :lt then '<'
              when :lte then '<='
              when :not then inequality_operator(value)
              when :eql then equality_operator(value)
              when :like then equality_operator(value, 'LIKE')
              when :in then equality_operator(value)
              else raise ArgumentError.new('Operator type not supported')
              end
              collector << ["#{primary_class_table[clause].to_sql(qualify_columns)} #{operator} ?", value]
            when Symbol then
              collector << ["#{primary_class_table[clause].to_sql(qualify_columns)} #{equality_operator(value)} ?", value]
            when String then
              collector << [clause, *value]
            when Mappings::Column then
              collector << ["#{clause.to_sql(qualify_columns)} #{equality_operator(value)} ?", value]
            else raise "CAN HAS CRASH? #{clause.inspect}"
            end
          rescue => e
            if e.is_a?(ConditionsError)
              raise e
            else
              raise ConditionsError.new(clause, value, e)
            end
          end
          
          private            
            # Return the Sql-escaped columns names to be selected in the results.
            def columns_for_select
              @columns_for_select || begin
                qualify_columns = qualify_columns?
                @columns_for_select = []
                
                i = 0
                columns.each do |column|
                  class_for_loader = column.table.klass
                  @loaders[class_for_loader].add_column(column, i) if class_for_loader
                  @columns_for_select << column.to_sql(qualify_columns)
                  i += 1
                end
                
                @columns_for_select
              end
              
            end
            
            # Returns the DataMapper::Adapters::Sql::Mappings::Column instances to
            # be selected in the results.
            def columns
              @columns || begin
                @columns = primary_class_columns
                @columns += included_columns
                
                included_associations.each do |assoc|
                  @columns += assoc.associated_columns
                end
                
                shallow_included_associations.each do |assoc|
                  @columns += assoc.join_columns
                end
                
                @columns
              end
            end
            
            # Returns the default columns for the primary_class_table,
            # or maps symbols specified in a +:select+ option to columns
            # in the primary_class_table.
            def primary_class_columns
              @primary_class_columns || @primary_class_columns = begin
                if @options.has_key?(:select)
                  case x = @options[:select]
                  when Array then x
                  when Symbol then [x]
                  else raise ':select option must be a Symbol, or an Array of Symbols'
                  end.map { |name| primary_class_table[name] }
                else
                  primary_class_table.columns.reject { |column| column.lazy? }
                end
              end
            end
            
            def included_associations
              @included_associations || @included_associations = begin
                associations = primary_class_table.associations
                include_options.map do |name|
                  associations[name]
                end.compact
              end
            end
            
            def shallow_included_associations
              @shallow_included_associations || @shallow_included_associations = begin
                associations = primary_class_table.associations
                shallow_include_options.map do |name|
                  associations[name]
                end.compact
              end
            end
            
            def included_columns
              @included_columns || @included_columns = begin
                include_options.map do |name|
                  primary_class_table[name]
                end.compact
              end
            end
            
            def include_options
              @include_options || @include_options = begin
                case x = @options[:include]
                when Array then x
                when Symbol then [x]
                else []
                end
              end
            end
            
            def shallow_include_options
              @shallow_include_options || @shallow_include_options = begin
                case x = @options[:shallow_include]
                when Array then x
                when Symbol then [x]
                else []
                end
              end
            end
            
            # Determine if a Column should be included based on the
            # value of the +:include+ option.
            def include_column?(name)
              !primary_class_table[name].lazy? || include_options.includes?(name)
            end

            # Return the Sql-escaped table name of the +primary_class+.
            def from_table_name
              @from_table_name || (@from_table_name = @adapter.table(@primary_class).to_sql)
            end
            
            # Returns the DataMapper::Adapters::Sql::Mappings::Table for the +primary_class+.
            def primary_class_table
              @primary_class_table || (@primary_class_table = @adapter.table(@primary_class))
            end
            
            def parse_conditions(conditions_hash)
              collection = []

              case x = conditions_hash.delete(:conditions)
              when Array then
                # DO NOT mutate incoming Array values!!!
                # Otherwise the mutated version may impact all the
                # way up to the options passed to the finders,
                # and have unintended side-effects.
                array_copy = x.dup
                clause = array_copy.shift
                expression_to_sql(clause, array_copy, collection)
              when Hash then
                x.each_pair do |key,value|
                  expression_to_sql(key, value, collection)
                end
              else
                raise "Unable to parse conditions: #{x.inspect}" if x
              end
              
              if primary_class_table.paranoid?
                conditions_hash[primary_class_table.paranoid_column.name] = nil
              end
              
              conditions_hash.each_pair do |key,value|
                expression_to_sql(key, value, collection)
              end

              collection              
            end

            def equality_operator(value, default = '=')
              case value
              when NilClass then 'IS'
              when Array then 'IN'
              else default
              end
            end

            def inequality_operator(value, default = '<>')
              case value
              when NilClass then 'IS NOT'
              when Array then 'NOT IN'
              else default
              end
            end
          
        end # class LoadCommand
      end # module Commands
    end # module Sql
  end # module Adapters
end # module DataMapper