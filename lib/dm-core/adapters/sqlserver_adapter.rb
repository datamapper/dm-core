require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

gem 'do_sqlserver', '~>0.0.1'
require 'do_sqlserver'

module DataMapper
  module Adapters
    class SqlserverAdapter < DataObjectsAdapter
      module SQL #:nodoc:
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
          '"'+name.gsub(/"/,'""')+'"'
        end
      end #module SQL

      include SQL
    end # class SqlserverAdapter

    const_added(:SqlserverAdapter)
  end # module Adapters
end # module DataMapper
