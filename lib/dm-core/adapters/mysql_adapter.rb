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

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_name(name)
          escaped = name.gsub('`', '``')

          if escaped.include?('.')
            escaped.split('.').map { |part| "`#{part}`" }.join('.')
          else
            escaped
          end
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_value(value)
          case value
            when TrueClass  then super(1)
            when FalseClass then super(0)
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
