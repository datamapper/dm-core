require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

require 'do_oracle'

module DataMapper

  class Property
    # for custom sequence names
    OPTIONS << :sequence
  end

  module Adapters
    class OracleAdapter < DataObjectsAdapter
      module SQL #:nodoc:
        IDENTIFIER_MAX_LENGTH = 30

        private

        # Constructs INSERT statement for given query,
        #
        # @return [String] INSERT statement as a string
        #
        # @api private
        def insert_statement(model, properties, serial)
          statement = "INSERT INTO #{quote_name(model.storage_name(name))} "

          custom_sequence = serial && serial.options[:sequence]

          if supports_default_values? && properties.empty? && !custom_sequence
            statement << "(#{quote_name(serial.field)}) " if serial
            statement << default_values_clause
          else
            # do not use custom sequence if identity field was assigned a value
            if custom_sequence && properties.include?(serial)
              custom_sequence = nil
            end
            statement << "("
            if custom_sequence
              statement << "#{quote_name(serial.field)}"
              statement << ", " unless properties.empty?
            end
            statement << "#{properties.map { |p| quote_name(p.field) }.join(', ')}) "
            statement << "VALUES ("
            if custom_sequence
              statement << "#{quote_name(custom_sequence)}.NEXTVAL"
              statement << ", " unless properties.empty?
            end
            statement << "#{(['?'] * properties.size).join(', ')})"
          end

          if supports_returning? && serial
            statement << returning_clause(serial)
          end

          statement
        end

        # Oracle syntax for inserting default values
        def default_values_clause
          'VALUES (DEFAULT)'
        end

        # TODO: document
        # @api private
        def supports_returning?
          true
        end

        # INTO :insert_id is recognized by Oracle DataObjects driver
        def returning_clause(serial)
          " RETURNING #{quote_name(serial.field)} INTO :insert_id"
        end

        # Constructs SELECT statement for given query,
        # Overrides DataObjects adapter implementation with using subquery instead of GROUP BY to get unique records
        #
        # @return [String] SELECT statement as a string
        #
        # @api private
        def select_statement(query)
          model      = query.model
          fields     = query.fields
          conditions = query.conditions
          limit      = query.limit
          offset     = query.offset
          order      = query.order
          group_by   = nil

          # FIXME: using a boolean for qualify does not work in some cases,
          # such as when you have a self-referrential many to many association.
          # if you don't qualfiy the columns with a unique alias, then the
          # SQL query will fail.  This may mean though, that it might not
          # be enough to pass in a Property, but we may need to know the
          # table and the alias we should use for the column.

          qualify = query.links.any?

          if query.unique?
            group_by = fields.select { |p| p.kind_of?(Property) }
          end

          # create subquery to find all valid keys and then use these keys to retrive all other columns
          use_subquery = qualify

          # when we can include ROWNUM condition in main WHERE clause
          use_simple_rownum_limit = limit && (offset||0 == 0) && group_by.blank? && order.blank?

          unless (limit && limit > 1) || offset > 0 || qualify
            # TODO: move this method to Query, so that it walks the conditions
            # and finds an OR operator

            # TODO: handle cases where two or more properties need to be
            # used together to be unique

            # if a unique property is used, and there is no OR operator, then an ORDER
            # and LIMIT are unecessary because it should only return a single row
            if conditions.kind_of?(Query::Conditions::AndOperation) &&
               conditions.any? { |operand| operand.kind_of?(Query::Conditions::EqualToComparison) && operand.subject.respond_to?(:unique?) && operand.subject.unique? } &&
               !conditions.any? { |operand| operand.kind_of?(Query::Conditions::OrOperation) }
              order = nil
              limit = nil
            end
          end

          conditions_statement, bind_values = conditions_statement(conditions, qualify)

          statement = "SELECT #{columns_statement(fields, qualify)}"
          if use_subquery
            statement << " FROM #{quote_name(model.storage_name(name))}"
            statement << " WHERE (#{columns_statement(model.key, qualify)}) IN"
            statement << " (SELECT DISTINCT #{columns_statement(model.key, qualify)}"
          end
          statement << " FROM #{quote_name(model.storage_name(name))}"
          statement << join_statement(query, qualify)                      if qualify
          statement << " WHERE (#{conditions_statement})"                  unless conditions_statement.blank?
          if use_subquery
            statement << ")"
          end
          if use_simple_rownum_limit
            statement << " AND rownum <= ?"
            bind_values << limit
          end
          statement << " GROUP BY #{columns_statement(group_by, qualify)}" unless group_by.blank?
          statement << " ORDER BY #{order_statement(order, qualify)}"      unless order.blank?

          add_limit_offset!(statement, limit, offset, bind_values) unless use_simple_rownum_limit

          return statement, bind_values
        end

        # Oracle does not support LIMIT and OFFSET
        # Functionality is mimiced through the use of nested selects.
        # See http://asktom.oracle.com/pls/ask/f?p=4950:8:::::F4950_P8_DISPLAYID:127412348064
        def add_limit_offset!(statement, limit, offset, bind_values)
          if limit && offset > 0
            statement.replace "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{statement}) raw_sql_ where rownum <= ?) where raw_rnum_ > ?"
            bind_values << offset + limit << offset
          elsif limit
            statement.replace "select raw_sql_.* from (#{statement}) raw_sql_ where rownum <= ?"
            bind_values << limit
          elsif offset > 0
            statement.replace "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{statement}) raw_sql_) where raw_rnum_ > ?"
            bind_values << offset
          end
        end

        # TODO: document
        # @api private
        # Oracle does not allow " in table or column names therefore substitute them with underscore
        def quote_name(name)
          "\"#{oracle_upcase(name)[0, self.class::IDENTIFIER_MAX_LENGTH].gsub('"', '_')}\""
        end

        # If table or column name contains just lowercase characters then do uppercase
        # as uppercase version will be used in Oracle data dictionary tables
        def oracle_upcase(name)
          name =~ /[A-Z]/ ? name : name.upcase
        end

        # CLOB value should be compared using DBMS_LOB.SUBSTR function
        # NOTE: just first 32767 bytes will be compared!
        # @api private
        def equality_operator(property, operand)
          if property.type == Types::Text
            operand.nil? ? 'IS' : 'DBMS_LOB.SUBSTR(%s) = ?'
          else
            operand.nil? ? 'IS' : '='
          end
        end

        # CLOB value should be compared using DBMS_LOB.SUBSTR function
        # NOTE: just first 32767 bytes will be compared!
        # @api private
        def inequality_operator(property, operand)
          if property.type == Types::Text
            operand.nil? ? 'IS NOT' : 'DBMS_LOB.SUBSTR(%s) <> ?'
          else
            operand.nil? ? 'IS NOT' : '<>'
          end
        end

        # TODO: document
        # @api private
        def include_operator(property, operand)
          operator = case operand
            when Array then 'IN'
            when Range then 'BETWEEN'
          end
          if property.type == Types::Text
            "DBMS_LOB.SUBSTR(%s) #{operator} ?"
          else
            operator
          end
        end

        # TODO: document
        # @api private
        def exclude_operator(property, operand)
          operator = case operand
            when Array then 'NOT IN'
            when Range then 'NOT BETWEEN'
          end
          if property.type == Types::Text
            "DBMS_LOB.SUBSTR(%s) #{operator} ?"
          else
            operator
          end
        end

        # TODO: document
        # @api private
        def regexp_operator(operand)
          'REGEXP_LIKE(%s, ?)'
        end

        # TODO: document
        # @api private
        def not_regexp_operator(operand)
          'NOT REGEXP_LIKE(%s, ?)'
        end

      end #module SQL

      include SQL
    end # class PostgresAdapter

    const_added(:OracleAdapter)
  end # module Adapters
end # module DataMapper
