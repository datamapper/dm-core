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
          qualify  = query.links.any?
          fields   = query.fields
          order_by = query.order
          group_by = if qualify || query.unique?
            fields.select { |property| property.kind_of?(Property) }
          end

          conditions_statement, bind_values = conditions_statement(query.conditions, qualify)

          use_limit_offset_subquery = query.limit && query.offset > 0

          if use_limit_offset_subquery
            # If using qualifiers, we must qualify elements outside the subquery
            # with 'RowResults' -- this is a different scope to the subquery.
            # Otherwise, we hit upon "multi-part identifier cannot be bound"
            # error from SQL Server.
            statement = "SELECT #{columns_statement(fields, qualify, 'RowResults')}"
            statement << " FROM ( SELECT Row_Number() OVER (ORDER BY #{order_statement(order_by, qualify)}) AS RowID,"
            statement << " #{columns_statement(fields, qualify)}"
            statement << " FROM #{quote_name(query.model.storage_name(name))}"
            statement << join_statement(query, qualify)                      if qualify
            statement << " WHERE #{conditions_statement}"                    unless conditions_statement.blank?
            statement << ") AS RowResults"
            statement << " WHERE RowId > #{query.offset} AND RowId <= #{query.offset + query.limit}"
            statement << " GROUP BY #{columns_statement(group_by, qualify, 'RowResults')}" if group_by && group_by.any?
            statement << " ORDER BY #{order_statement(order_by, qualify, 'RowResults')}"   if order_by && order_by.any?
          else
            statement = "SELECT #{columns_statement(fields, qualify)}"
            statement << " FROM #{quote_name(query.model.storage_name(name))}"
            statement << join_statement(query, qualify)                      if qualify
            statement << " WHERE #{conditions_statement}"                    unless conditions_statement.blank?
            statement << " GROUP BY #{columns_statement(group_by, qualify)}" if group_by && group_by.any?
            statement << " ORDER BY #{order_statement(order_by, qualify)}"   if order_by && order_by.any?
          end

          add_limit_offset!(statement, query.limit, query.offset, bind_values) unless use_limit_offset_subquery

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

        # TODO: document
        # @api private
        # TODO: Not actually supported out of the box. Is theoretically possible
        # via CLR integration, custom functions.
        def regexp_operator(operand)
          'REGEXP'
        end

        # TODO: document
        # @api private
        # TODO: Not actually supported out of the box. Is theoretically possible
        # via CLR integration, custom functions.
        def not_regexp_operator(operand)
          'NOT REGEXP'
        end

      end #module SQL

      include SQL
    end # class SqlserverAdapter

    const_added(:SqlserverAdapter)
  end # module Adapters
end # module DataMapper
