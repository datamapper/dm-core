require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

gem 'do_mysql', '~>0.9.12'
require 'do_mysql'

module DataMapper
  module Adapters
    class MysqlAdapter < DataObjectsAdapter
      module SQL #:nodoc:
        private

        def supports_default_values?
          false
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_name(name)
          "`#{name.gsub('`', '``')}`"
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

    const_added(:MysqlAdapter)
  end # module Adapters
end # module DataMapper
