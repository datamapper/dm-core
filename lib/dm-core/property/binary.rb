module DataMapper
  class Property
    class Binary < String
      include PassThroughLoadDump

      def load(value)
        super.force_encoding("BINARY") if value
      end

      def dump(value)
        super.force_encoding("BINARY") if value
      end
      
    end # class Binary
  end # class Property
end # module DataMapper
