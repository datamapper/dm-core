module DataMapper
  module Adapters
    module Sql
      module Mappings
        
        class Conditions
          def initialize(table, adapter, qualify_columns=false, options={})
            @table = table
            @qualify_columns = qualify_columns
            
            # BEGIN: Partion out the options hash into general options,
            # and conditions.
            standard_find_options = adapter.class::FIND_OPTIONS
            conditions_hash = {}
            
            options.each do |key,value|
              unless standard_find_options.include?(key) && key != :conditions
                conditions_hash[key] = value
              end
            end
            # END
            
            @conditions = parse_conditions(conditions_hash)
          end
        
          # Generate a statement after 'WHERE' based on the initialization
          # arguments.
          def to_params_sql
            parameters = []
            sql = ""
          
            unless @conditions.empty?
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
            end
            
            parameters.unshift(sql)
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
            
            if @table.paranoid?
              conditions_hash[@table.paranoid_column.name] = nil
            end
            
            conditions_hash.each_pair do |key,value|
              expression_to_sql(key, value, collection)
            end

            collection              
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
              #Table[column name] is column.to_sql(true/false based on associations or not)
              collector << ["#{@table[clause].to_sql(@qualify_columns)} #{operator} ?", value]
            when Symbol then
              collector << ["#{@table[clause].to_sql(@qualify_columns)} #{equality_operator(value)} ?", value]
            when String then
              collector << [clause, *value]
            when Mappings::Column then
              collector << ["#{clause.to_sql(@qualify_columns)} #{equality_operator(value)} ?", value]
            else raise "CAN HAS CRASH? #{clause.inspect}"
            end
          rescue => e
            raise ConditionsError.new(clause, value, e)
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
                  
        end
      end
    end
  end
end
