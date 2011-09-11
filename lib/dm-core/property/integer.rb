module DataMapper
  class Property
    class Integer < Numeric
      load_as         ::Integer
      coercion_method :to_integer

      accept_options :serial

    protected

      # @api semipublic
      def initialize(model, name, options = {})
        if options.key?(:serial) && !kind_of?(Serial)
          raise "Integer #{name} with explicit :serial option is deprecated, use Serial instead (#{caller[2]})"
        end
        super
      end

    end # class Integer
  end # class Property
end # module DataMapper
