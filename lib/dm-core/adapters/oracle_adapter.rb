require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

require 'do_oracle'

module DataMapper
  module Adapters
    class OracleAdapter < DataObjectsAdapter
      module SQL #:nodoc:
        IDENTIFIER_MAX_LENGTH = 30

        private

        # TODO: document
        # @api private
        def supports_returning?
          true
        end

        # INTO :insert_id is recognized by Oracle DataObjects driber
        def returning_clause(identity_field)
          " RETURNING #{quote_name(identity_field.field)} INTO :insert_id"
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
            statement.replace "select raw_sql_.* from (#{statement}) raw_sql_ where rownum > ?"
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
