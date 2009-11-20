require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

require 'do_sqlserver'

DataObjects::Sqlserver = DataObjects::SqlServer

module DataMapper
  module Adapters
    class SqlserverAdapter < DataObjectsAdapter
      module SQL #:nodoc:
        private

        # Constructs INSERT statement for given query,
        #
        # @return [String] INSERT statement as a string
        #
        # @api private
        def insert_statement(model, properties, serial)
          statement = ""
          # Check if there is a serial property being set directly
          require_identity_insert = !properties.empty? && properties.any? { |property| property.serial? }
          set_identity_insert(model, statement, true) if require_identity_insert
          statement << super
          set_identity_insert(model, statement, false) if require_identity_insert
          statement
        end

        def set_identity_insert(model, statement, enable = true)
          statement << " SET IDENTITY_INSERT #{quote_name(model.storage_name(name))} #{enable ? 'ON' : 'OFF'} "
        end

        def select_statement(query)
          name     = self.name
          qualify  = query.links.any?
          fields   = query.fields
          offset   = query.offset
          limit    = query.limit
          order_by = query.order
          group_by = if qualify || query.unique?
            fields.select { |property| property.kind_of?(Property) }
          end

          conditions_statement, bind_values = conditions_statement(query.conditions, qualify)

          use_limit_offset_subquery = limit && offset > 0

          columns_statement = columns_statement(fields, qualify)
          from_statement    = " FROM #{quote_name(query.model.storage_name(name))}"
          where_statement   = " WHERE #{conditions_statement}" unless conditions_statement.blank?
          join_statement    = join_statement(query, qualify)
          order_statement   = order_statement(order_by, qualify)
          no_group_by       = group_by ? group_by.empty? : true
          no_order_by       = order_by ? order_by.empty? : true

          if use_limit_offset_subquery
            # If using qualifiers, we must qualify elements outside the subquery
            # with 'RowResults' -- this is a different scope to the subquery.
            # Otherwise, we hit upon "multi-part identifier cannot be bound"
            # error from SQL Server.
            statement = "SELECT #{columns_statement(fields, qualify, 'RowResults')}"
            statement << " FROM ( SELECT Row_Number() OVER (ORDER BY #{order_statement}) AS RowID,"
            statement << " #{columns_statement}"
            statement << from_statement
            statement << join_statement                                      if qualify
            statement << where_statement                                     if where_statement
            statement << ") AS RowResults"
            statement << " WHERE RowId > #{offset} AND RowId <= #{offset + limit}"
            statement << " GROUP BY #{columns_statement(group_by, qualify, 'RowResults')}" unless no_group_by
            statement << " ORDER BY #{order_statement(order_by, qualify, 'RowResults')}"   unless no_order_by
          else
            statement = "SELECT #{columns_statement}"
            statement << from_statement
            statement << join_statement                                      if qualify
            statement << where_statement                                     if where_statement
            statement << " GROUP BY #{columns_statement(group_by, qualify)}" unless no_group_by
            statement << " ORDER BY #{order_statement}"   unless no_order_by
          end

          add_limit_offset!(statement, limit, offset, bind_values) unless use_limit_offset_subquery

          return statement, bind_values
        end

        # SQL Server does not support LIMIT and OFFSET
        # Functionality therefore must be mimicked through the use of nested selects.
        # See also:
        # - http://stackoverflow.com/questions/2840/paging-sql-server-2005-results
        # - http://stackoverflow.com/questions/216673/emulate-mysql-limit-clause-in-microsoft-sql-server-2000
        #
        def add_limit_offset!(statement, limit, offset, bind_values)
          # Limit and offset is handled by subqueries (see #select_statement).
          if limit
            # If there is just a limit on rows to return, but no offset, then we
            # can use TOP clause.
            statement.sub!(/^\s*SELECT(\s+DISTINCT)?/i) { "SELECT#{$1} TOP #{limit}" }
            # bind_values << limit
          end
        end

        # @api private
        # TODO: Not actually supported out of the box. Is theoretically possible
        # via CLR integration, custom functions.
        def regexp_operator(operand)
          'REGEXP'
        end

      end #module SQL

      include SQL
    end # class SqlserverAdapter

    const_added(:SqlserverAdapter)
  end # module Adapters
end # module DataMapper
