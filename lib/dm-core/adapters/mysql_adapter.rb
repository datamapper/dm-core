require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

require 'do_mysql'

module DataMapper
  module Adapters
    class MysqlAdapter < DataObjectsAdapter
      module SQL #:nodoc:
        IDENTIFIER_MAX_LENGTH = 64

        private

        # TODO: document
        # @api private
        def supports_default_values? #:nodoc:
          false
        end

        # TODO: document
        # @api private
        def regexp_operator(operand)
          'REGEXP'
        end

        # TODO: document
        # @api private
        def not_regexp_operator(operand)
          'NOT REGEXP'
        end

        # TODO: document
        # @api private
        def quote_name(name)
          "`#{name[0, self.class::IDENTIFIER_MAX_LENGTH].gsub('`', '``')}`"
        end
      end #module SQL

      include SQL
    end # class MysqlAdapter

    const_added(:MysqlAdapter)
  end # module Adapters
end # module DataMapper
