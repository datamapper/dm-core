#require __DIR__ + 'property'

module DataMapper
  class Type
    #TODO: figure out a way to read this from DataMapper::Property without cyclic require(s)
    #This should ALWAYS mirror DataMapper::Property::PROPERTY_OPTIONS, with the exception of aliases
    PROPERTY_OPTIONS = [ :public, :protected, :private, :accessor, :reader,
      :writer, :lazy, :default, :nullable, :key, :serial, :field, :size,
      :format, :index, :check, :ordinal, :auto_validation ]
      
    PROPERTY_OPTION_ALIASES = {
      :size => [ :length ]
    }
      
    class << self
      #attr_accessor :primitive #map to Ruby type
      
      def primitive(primitive = nil)
        return @primitive if primitive.nil?
        
        @primitive = primitive
      end

      #load DataMapper::Property options
      PROPERTY_OPTIONS.each do |property_option|
        self.class_eval <<-EOS
        def #{property_option}(arg = nil)
          return @#{property_option} if arg.nil?
          
          @#{property_option} = arg
        end
        EOS
      end
      
      #create property aliases
      PROPERTY_OPTION_ALIASES.each do |property_option, aliases|
        aliases.each do |ali|
          self.class_eval <<-EOS
          def #{ali}(arg = nil)
            #{property_option}(arg)
          end
          EOS
        end
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