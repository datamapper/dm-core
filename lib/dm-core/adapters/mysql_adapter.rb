gem 'do_mysql', '~>0.9.10'
require 'do_mysql'

module DataMapper
  module Adapters
    # Options:
    # host, user, password, database (path), socket(uri query string), port
    class MysqlAdapter < DataObjectsAdapter
      module SQL
        private

        def supports_default_values?
          false
        end

        def escape_name(name)
          name.gsub('`', '``')
        end

        def quote_name(name)
          if name.include?('.')
            escape_name(name).split('.').map { |part| "`#{part}`" }.join('.')
          else
            escape_name(name)
          end
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        alias quote_table_name quote_name

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        alias quote_column_name quote_name

        def quote_column_value(column_value)
          case column_value
            when TrueClass  then quote_column_value(1)
            when FalseClass then quote_column_value(0)
            else
              super
          end
        end

        def like_operator(operand)
          operand.kind_of?(Regexp) ? 'REGEXP' : 'LIKE'
        end

      end #module SQL

      include SQL
    end # class MysqlAdapter
  end # module Adapters
end # module DataMapper
