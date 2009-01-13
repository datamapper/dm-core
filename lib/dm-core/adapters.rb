require Pathname(__FILE__).dirname.expand_path / 'adapters' / 'abstract_adapter'

module DataMapper
  module Adapters
    def self.extendable(&block)
      mod = Module.new(&block)
      extend mod
      mod
    end

    extendable do
      def const_added(const_name)
      end
    end
  end # module Adapters
end # module DataMapper
