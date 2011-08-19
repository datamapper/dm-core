module DataMapper
  class Property
    class String < Object
      include PassThroughLoadDump

      primitive ::String

      accept_options :length

      DEFAULT_LENGTH = 50
      length(DEFAULT_LENGTH)

      # Returns maximum property length (if applicable).
      # This usually only makes sense when property is of
      # type Range or custom
      #
      # @return [Integer, nil]
      #   the maximum length of this property
      #
      # @api semipublic
      def length
        if @length.kind_of?(Range)
          @length.max
        else
          @length
        end
      end

      protected

      def initialize(model, name, options = {})
        super
        @length = @options.fetch(:length)
      end

      # Typecast a value to a String
      #
      # @param [#to_s] value
      #   value to typecast
      #
      # @return [String]
      #   String constructed from value
      #
      # @api private
      def typecast_to_primitive(value)
        value.to_s
      end
    end # class String
  end # class Property
end # module DataMapper
