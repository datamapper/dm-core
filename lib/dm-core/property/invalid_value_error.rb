module DataMapper
  class Property
    # Exception raised when DataMapper is about to work with
    # invalid property values.
    class InvalidValueError < StandardError
      attr_reader :property, :value

      def initialize(property, value)
        msg = "Invalid value %s for property %s (%s) on model %s" %
          [ value.inspect,
            property.name.inspect,
            property.class.name,
            property.model.name
          ]
        super(msg)
        @property = property
        @value = value
      end

    end # class InvalidValueError
  end # class Property
end # module DataMapper
