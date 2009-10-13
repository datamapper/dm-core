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

        # SQL Server does not support LIMIT and OFFSET
        # Functionality therefore must be mimicked through the use of nested selects.
        # See also:
        # http://stackoverflow.com/questions/216673/emulate-mysql-limit-clause-in-microsoft-sql-server-2000
        #
        # This implementation is taken from ActiveRecordJDBC project's
        # TSqlMethods module (MIT-Licensed, and attributed in the commit log to
        # Ryan Bell (kofno)).
        def add_limit_offset!(statement, limit, offset, bind_values)
          if limit and offset
            total_rows = select("SELECT count(*) as TotalRows from (#{statement.gsub(/\bSELECT(\s+DISTINCT)?\b/i, "SELECT\\1 TOP 1000000000")}) tally", *bind_values).first.to_i
            if (limit + offset) >= total_rows
              limit = (total_rows - offset >= 0) ? (total_rows - offset) : 0
            end
            statement.sub!(/^\s*SELECT(\s+DISTINCT)?/i, "SELECT * FROM (SELECT TOP #{limit} * FROM (SELECT\\1 TOP #{limit + offset} ")
            statement << ") AS tmp1"
            statement << " ) AS tmp2"
          elsif statement !~ /^\s*SELECT (@@|COUNT\()/i
            statement.sub!(/^\s*SELECT(\s+DISTINCT)?/i) do
              "SELECT#{$1} TOP #{limit}"
            end unless limit.nil?
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
