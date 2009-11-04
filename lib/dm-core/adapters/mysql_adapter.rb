require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

require 'do_mysql'

module DataMapper
  module Adapters
    class MysqlAdapter < DataObjectsAdapter
      module SQL #:nodoc:
        IDENTIFIER_MAX_LENGTH = 64

        private

        # @api private
        def supports_default_values? #:nodoc:
          false
        end

        # @api private
        def supports_subquery?(query, source_key, target_key, qualify)
          # TODO: renable once query does not include target_model for deletes and updates
          # query.limit.nil?

          false
        end

        # @api private
        def regexp_operator(operand)
          'REGEXP'
        end

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
