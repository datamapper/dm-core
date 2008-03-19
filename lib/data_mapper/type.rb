#require __DIR__ + 'property'

module DataMapper
  class Type
    #TODO: figure out a way to read this from DataMapper::Property without cyclic require(s)
    #This should ALWAYS mirror DataMapper::Property::PROPERTY_OPTIONS
    PROPERTY_OPTIONS = [ :public, :protected, :private, :accessor, :reader, :writer, :lazy,
      :default, :nullable, :key, :serial, :field, :size, :length,
      :format, :index, :check, :ordinal, :auto_validation ]
      
    class << self
      #attr_accessor :primitive #map to Ruby type
      
      def primitive(primitive = nil)
        return @primitive if primitive.nil?
        
        @primitive = primitive
      end

      #load DataMapper::Property options
      # DataMapper::Property::PROPERTY_OPTIONS.each do |property_option|
      PROPERTY_OPTIONS.each do |property_option|
        # attr_accessor property_option
        
        self.class_eval <<-EOS
        def #{property_option}(#{property_option} = nil)
          return @#{property_option} if #{property_option}.nil?
          
          @#{property_option} = #{property_option}
        end
        EOS
      end

      def options
        PROPERTY_OPTIONS.inject({}) do |options, method|
          value = send(method)
          options[method.to_sym] = value unless value.nil?; options
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