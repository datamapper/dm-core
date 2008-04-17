module DataMapper
  module Types
    class Csv < DataMapper::Type
      primitive String
      size 65535
      lazy true

      def self.load(value, property)
        case value
        when String then FasterCSV.parse(value)
        when Array then value
        else nil
        end
      end

      def self.dump(value, property)
        case value
        when Array then
          FasterCSV.generate do |csv|
            value.each { |row| csv << row }
          end
        when String then value
        else nil
        end  
      end
    end # class Csv
  end # module Types  
end # module DataMapper