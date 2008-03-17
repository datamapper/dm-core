module DataMapper
  
  # This class handles option parsing and SQL generation.
  class Query
    
    # These are the standard finder options
    OPTIONS = [
      :select, :offset, :limit, :include, :reload, :conditions, :join, :order, :after_row_materialization
    ]
    
    def initialize(adapter, klass, options = {})
      # Set some of the standard options
      @adapter, @klass = adapter, klass
      @from = @adapter.table(@klass)
      @parameters = []
      @joins = []
      
      # Parse simple options
      @limit =          options.fetch(:limit, nil)
      @offset =         options.fetch(:offset, nil)
      @reload =         options.fetch(:reload, false)
      @order =          options.fetch(:order, nil)
      @after_row_materialization = options.fetch(:after_row_materialization, nil)
      
      # Parse :include option
      @includes = case include_options = options[:include]
        when Array then include_options.dup
        when Symbol then [include_options]
        when NilClass then []
        else raise ArgumentError.new(":include must be an Array, Symbol or nil, but was #{include_options.inspect}")
      end
      
      # Include lazy columns if specified in :include option
      @columns = @from.columns.select do |column|
        !column.lazy? || @includes.delete(column.name)
      end
      
      # Qualify columns with their table name if joins are present
      @qualify = !@includes.empty?
      
      # Generate SQL for joins
      @includes.each do |association_name|
        association = @from.associations[association_name]
        @joins << association.to_sql
        @columns += association.associated_table.columns.select do |column|
          !column.lazy?
        end
      end
      
      # Prepare conditions for parsing
      @conditions = []
      
      # Each non-standard option is assumed to be a column
      options.each_pair do |k,v|
        unless OPTIONS.include?(k)
          append_condition(k, v)
        end
      end
      
      # If a :conditions option is present, parse it
      if conditions_option = options[:conditions]
        if conditions_option.is_a?(String)
          @conditions << conditions_option
        else
          append_condition(*conditions_option)
        end
      end
      
      # If the table is paranoid, add a filter to the conditions
      if @from.paranoid?
        @conditions << "#{@from.paranoid_column.to_sql(qualify?)} IS NULL OR #{@from.paranoid_column.to_sql(qualify?)} > #{@adapter.class::SYNTAX[:now]}"
      end
      
    end
    
    # SQL for query
    def to_sql
      sql = "SELECT #{columns.map { |column| column.to_sql(qualify?) }.join(', ')} FROM #{from.to_sql}"
      
      sql << " " << joins.join($/) unless joins.empty?
      sql << " WHERE (#{conditions.join(") AND (")})" unless conditions.empty?
      return sql
    end
    
    # Parameters for query
    def parameters
      @parameters
    end
    
    private
    
    # Conditions for the query, in the form of an Array of Strings
    def conditions
      @conditions
    end
    
    # Determines wether columns should be qualified with their table-names.
    def qualify?
      @qualify
    end
    
    # The primary table in the FROM clause of the query
    def from
      @from
    end
    
    # SQL for any joins in the query
    def joins
      @joins
    end
    
    # Column mappings to be selected
    def columns
      @columns
    end
    
    def append_condition(clause, value)
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
          @conditions << "#{from[clause].to_sql(qualify?)} #{operator} ?"
          @parameters << value
        when Symbol then
          @conditions << "#{from[clause].to_sql(qualify?)} #{equality_operator(value)} ?"
          @parameters << value
        when String then
          @conditions << clause
          value.each { |v| @parameters << v }
        when Mappings::Column then
          @conditions << "#{clause.to_sql(qualify?)} #{equality_operator(value)} ?"
          @parameters << value
        else raise "CAN HAS CRASH? #{clause.inspect}"
      end
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
    
    
  end # class Query
end # module DataMapper