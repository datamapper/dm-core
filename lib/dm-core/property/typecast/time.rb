module DataMapper
  class Property
    module Typecast
      module Time
        include Numeric

        # Extracts the given args from the hash. If a value does not exist, it
        # uses the value of Time.now.
        #
        # @param [Hash, #to_mash] value
        #   value to extract time args from
        #
        # @return [Array]
        #   Extracted values
        #
        # @api private
        def extract_time(value)
          mash = if value.respond_to?(:to_mash)
                   value.to_mash
                 else
                   DataMapper::Ext::Hash.to_mash(value)
                 end

          now  = ::Time.now

          [ :year, :month, :day, :hour, :min, :sec ].map do |segment|
            typecast_to_numeric(mash.fetch(segment, now.send(segment)), :to_i)
          end
        end
      end # Time
    end # Typecast
  end # Property
end # DataMapper
