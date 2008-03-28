module DataMapper
  module Types
    class Flag < DataMapper::Type(Fixnum)
  
      def self.flag_map
        @flag_map
      end
  
      def self.flag_map=(value)
        @flag_map = value
      end
  
      def self.new(*flags)
        type = Flag.dup
        type.flag_map = {}
        
        flags.each_with_index do |flag, i|
          type.flag_map[2 ** i] = flag
        end
        
        type
      end
  
      def self.[](*flags)
        new(*flags)
      end
  
      def self.load(value)
        begin
          matches = []
          
          0.upto((Math.log(value) / Math.log(2)).ceil) do |i|
            pow = 2 ** i
            matches << flag_map[pow] if value & pow == pow
          end
          
          matches.compact
        rescue TypeError, Errno::EDOM
          []
        end
      end
  
      def self.dump(*flags)
        flag_map.invert.values_at(*flags.flatten).compact.inject(0) {|sum, i| sum + i}
      end
    end
  end
end