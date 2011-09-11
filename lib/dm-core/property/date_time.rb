module DataMapper
  class Property
    class DateTime < Object
      load_as         ::DateTime
      coercion_method :to_datetime

    end # class DateTime
  end # class Property
end # module DataMapper
