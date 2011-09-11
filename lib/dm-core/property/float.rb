module DataMapper
  class Property
    class Float < Numeric
      load_as         ::Float
      coercion_method :to_float

      DEFAULT_PRECISION = 10
      DEFAULT_SCALE     = nil

      precision(DEFAULT_PRECISION)
      scale(DEFAULT_SCALE)

    end # class Float
  end # class Property
end # module DataMapper
