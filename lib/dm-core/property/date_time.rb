require 'dm-core/property/typecast/time'

module DataMapper
  class Property
    class DateTime < Object
      include PassThroughLoadDump
      include Typecast::Time

      primitive ::DateTime

      # Typecasts an arbitrary value to a DateTime.
      # Handles both Hashes and DateTime instances.
      #
      # @param [Hash, #to_mash, #to_s] value
      #   value to be typecast
      #
      # @return [DateTime]
      #   DateTime constructed from value
      #
      # @api private
      def typecast_to_primitive(value)
        if value.is_a?(::Hash) || value.respond_to?(:to_mash)
          typecast_hash_to_datetime(value)
        else
          ::DateTime.parse(value.to_s)
        end
      rescue ArgumentError
        value
      end

      # Creates a DateTime instance from a Hash with keys :year, :month, :day,
      # :hour, :min, :sec
      #
      # @param [Hash, #to_mash] value
      #   value to be typecast
      #
      # @return [DateTime]
      #   DateTime constructed from hash
      #
      # @api private
      def typecast_hash_to_datetime(value)
        ::DateTime.new(*extract_time(value))
      end
    end # class DateTime
  end # class Property
end # module DataMapper
