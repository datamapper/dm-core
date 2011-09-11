module DataMapper
  class Property
    class Time < Object
      load_as         ::Time
      coercion_method :to_time

    end # class Time
  end # class Property
end # module DataMapper
