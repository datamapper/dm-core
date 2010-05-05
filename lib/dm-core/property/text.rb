module DataMapper
  class Property
    class Text < String
      length  65535
      lazy    true

      def primitive?(value)
        value.kind_of?(::String)
      end
    end # class Text
  end # class Property
end # module DataMapper
