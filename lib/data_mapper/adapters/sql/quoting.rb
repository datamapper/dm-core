module DataMapper
  module Adapters
    module Sql
      
      # Quoting is a mixin that extends your DataMapper::Repository singleton-class
      # to allow for object-name and value quoting to be exposed to the queries.
      #
      # DESIGN: Is there any need for this outside of the query objects? Should
      # we just include it in our query object subclasses and not rely on a Quoting
      # mixin being part of the "standard" Adapter interface?
      module Quoting

        def quote_table_name(name)
          name.ensure_wrapped_with(self.class::TABLE_QUOTING_CHARACTER)
        end

        def quote_column_name(name)
          name.ensure_wrapped_with(self.class::COLUMN_QUOTING_CHARACTER)
        end

      end # module Quoting
    end
  end
end
