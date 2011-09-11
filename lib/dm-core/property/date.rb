module DataMapper
  class Property
    class Date < Object
      load_as         ::Date
      coercion_method :to_date

    end # class Date
  end # class Property
end # module DataMapper
