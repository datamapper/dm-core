# TODO: move this to Extlib::Chainable

module DataMapper
  module Chainable
    def chainable(&block)
      mod = Module.new(&block)
      include mod
      mod
    end

    def extendable(&block)
      mod = Module.new(&block)
      extend mod
      mod
    end
  end # module Chainable
end # module DataMapper
