module DataMapper
  module Types
    class Enum < DataMapper::Type(Fixnum)
  
      def self.flag_map
        @flag_map
      end
  
      def self.flag_map=(value)
        @flag_map = value
      end
  
      def self.new(*flags)
        enum = Enum.dup
        enum.flag_map = {}
        
        flags.each_with_index do |flag, i|
          enum.flag_map[i + 1] = flag
        end
        
        enum
      end
  
      def self.[](*flags)
        new(*flags)
      end
  
      def self.load(value)
        self.flag_map[value]
      end
  
      def self.dump(flag)
        self.flag_map.invert[flag]
      end
    end
  end
end