module DataMapper
  class Property
    class Binary < String
      include PassThroughLoadDump

      if RUBY_VERSION >= "1.9"

        def load(value)
          super.dup.force_encoding("BINARY") unless value.nil?
        end

        def dump(value)
          value.dup.force_encoding("BINARY") unless value.nil?
        rescue
          value
        end

      end

    end # class Binary
  end # class Property
end # module DataMapper
