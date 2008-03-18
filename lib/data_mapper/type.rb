module DataMapper
  class Type
    
    class << self
      attr_accessor :primitive #map to Ruby type
      
      #load DataMapper::Property options
      DataMapper::Property::PROPERTY_OPTIONS.each do |property_option|
        attr_accessor property_option
      end

      def options
        public_methods.inject({}) do |h,m|
          h[m.to_sym] = send(m); h
        end
      end
    end
    
    def self.materialize(value)
      raise NotImplementedError
    end
    
    # Must return a value of type :primitive, or nil.
    def self.serialize(value)
      raise NotImplementedError
    end
    
  end #class Type
end #module DataMapper