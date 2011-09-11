module DataMapper
  class Property
    class String < Object
      load_as         ::String
      coercion_method :to_string

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

    end # class String
  end # class Property
end # module DataMapper
