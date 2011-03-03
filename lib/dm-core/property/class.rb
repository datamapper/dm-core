module DataMapper
  class Property
    class Class < Object
      include PassThroughLoadDump

      primitive ::Class

      # Typecast a value to a Class
      #
      # @param [#to_s] value
      #   value to typecast
      #
      # @return [Class]
      #   Class constructed from value
      #
      # @api private
      def typecast_to_primitive(value)
        DataMapper::Ext::Module.find_const(model, value.to_s)
      rescue NameError
        value
      end
    end # class Class
  end # class Property
end # module DataMapper
