require 'dm-core/property/typecast/time'

module DataMapper
  class Property
    class Time < Object
      include PassThroughLoadDump
      include Typecast::Time

      primitive ::Time

      # Typecasts an arbitrary value to a Time
      # Handles both Hashes and Time instances.
      #
      # @param [Hash, #to_mash, #to_s] value
      #   value to be typecast
      #
      # @return [Time]
      #   Time constructed from value
      #
      # @api private
      def typecast_to_primitive(value)
        if value.respond_to?(:to_time)
          value.to_time
        elsif value.is_a?(::Hash) || value.respond_to?(:to_mash)
          typecast_hash_to_time(value)
        else
          ::Time.parse(value.to_s)
        end
      rescue ArgumentError
        value
      end

      # Creates a Time instance from a Hash with keys :year, :month, :day,
      # :hour, :min, :sec
      #
      # @param [Hash, #to_mash] value
      #   value to be typecast
      #
      # @return [Time]
      #   Time constructed from hash
      #
      # @api private
      def typecast_hash_to_time(value)
        ::Time.local(*extract_time(value))
      end
    end # class Time
  end # class Property
end # module DataMapper
