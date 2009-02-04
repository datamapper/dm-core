class Module
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
end # class Module
