module DataMapper
  module Adapters
    extend Chainable

    extendable do
      def const_added(const_name)
      end
    end
  end # module Adapters
end # module DataMapper
