module DataMapper
  class Property
    class Boolean < Object
      load_as         ::TrueClass
      coercion_method :to_boolean

      # @api semipublic
      def value_dumped?(value)
        value == true || value == false
      end
    end # class Boolean
  end # class Property
end # module DataMapper
